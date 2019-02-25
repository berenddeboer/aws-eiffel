note

	description:

		"Class that can do packet size writes to S3"

	library: "s3 tools"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2009, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	S3_WRITER

inherit

	ANY

	EPX_CURRENT_PROCESS
		export
			{NONE} all
		end

	KL_IMPORTED_STRING_ROUTINES
		export
			{NONE} all
		end


create

	make


feature {NONE} -- Initialization

	make (a_region, a_bucket, a_key: READABLE_STRING_8; a_verbose: INTEGER)
		require
			bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
			key_not_empty: a_key /= Void and then not a_key.is_empty
		do
			set_part_size (67108864)
			create s3.make (a_region, a_bucket)
			set_verbose (a_verbose)
			key := a_key
			-- No error handling right now, will built retry when needed
			s3.set_continue_on_error
			display_waiting := true
			upload_id := ""
		end


feature -- Status

	something_read,
	something_written: BOOLEAN

	uploading: BOOLEAN
			-- Has a multipart upload process started?
		do
			Result := not upload_id.is_empty
		end


feature -- Access

	s3: S3_CLIENT

	key: STRING

	upload_id: STRING
			-- The identifier returned by S3 to be used for multi-part upload

	part_size: INTEGER
			-- Size of parts to upload; default is 64MB

	total_bytes_read,
	total_bytes_written: INTEGER_64

	verbose: INTEGER


feature -- Counters

	number_of_nonblocking_reads,
	number_of_blocking_reads,
	number_of_output_buffer_underflows,
	number_of_output_buffer_overflows,
	number_of_s3_retries: INTEGER


feature -- Change

	set_part_size (a_part_size: INTEGER)
		require
			minimum_part_size_is_5mb: a_part_size >= 5242880
		local
			buffer: S3_BUFFER
		do
			part_size := a_part_size
			create buffer.allocate (part_size)
			create ring_buffer.make (buffer)
			current_input_buffer := ring_buffer
			current_output_buffer := ring_buffer
			ring_buffer.put_right (create {like ring_buffer}.make (create {S3_BUFFER}.allocate (part_size)))
			if attached ring_buffer.right as right_buffer then
				right_buffer.put_right (create {like ring_buffer}.make (create {S3_BUFFER}.allocate (part_size)))
				if attached right_buffer.right as right_right_buffer then
					right_right_buffer.put_right (ring_buffer)
				end
			end
		ensure
			definition: part_size = a_part_size
		end

	set_verbose (a_verbose: INTEGER)
		do
			verbose := a_verbose
		ensure
			definition: verbose = a_verbose
		end


feature -- Writing

	close
		do
			if verbose > 0 then
				fd_stderr.put_line ("All input processed, finishing uploads.")
			end
			from
					check
						circular_buffer: attached current_input_buffer.right
					end
				if attached current_input_buffer.right as right_buffer then
					if current_output_buffer = current_input_buffer then
						current_input_buffer := right_buffer
						flush_output_buffer
					else
						flush_output_buffer
						current_input_buffer := right_buffer
					end
				end
			until
				current_output_buffer = current_input_buffer
			loop
				flush_output_buffer
			end

			-- Reset
			current_input_buffer := ring_buffer
			current_output_buffer := ring_buffer
			output_bytes_position := 0

			if uploading then
				s3.complete_multipart_upload (upload_id, key)
				if not s3.is_response_ok then
					fd_stderr.put_line ("Failed to complete multi-part upload.")
					if verbose > 0 then
						if attached s3.body as body then
							fd_stderr.put (body.as_string)
						end
					end
					exit_with_failure
				end
				upload_id.make_empty
			end
		end

	write (a_stream: ABSTRACT_DESCRIPTOR)
			-- Read all from `a_buffer' into our temporary storage, and
			-- pump out as much as possible to S3.
		require
			stream_not_void: a_stream /= Void
			open: a_stream.is_open_read
		local
			l_bytes_to_read: INTEGER
			l_input_buffer: S3_BUFFER
		do
			something_written := false
			-- First try if network likes some more
			--write_output_buffer

			-- Read as much from `a_stream' as possible
			number_of_nonblocking_reads := number_of_nonblocking_reads + 1
			l_input_buffer := current_input_buffer.item
			l_bytes_to_read := l_input_buffer.capacity - l_input_buffer.count
			a_stream.read_buffer (l_input_buffer, l_input_buffer.count, l_bytes_to_read)
			something_read := a_stream.last_read > 0
			if not something_read and then not something_written and then not a_stream.end_of_input then
				-- Nothing to read, and nothing written, just block till
				-- we have a full buffer.
				-- Note that we only get here when non-blocking i/o has
				-- been enabled.
				if verbose > 2 then
					fd_stderr.put_line ("Nothing to read or write, read input in blocking mode")
				end
				a_stream.set_blocking_io (True)
				number_of_blocking_reads := number_of_blocking_reads + 1
				a_stream.read_buffer (l_input_buffer, l_input_buffer.count, l_bytes_to_read)
				something_read := a_stream.last_read > 0
				if verbose > 2 then
					fd_stderr.put_line ("Read " + a_stream.last_read.out + " bytes in blocking mode")
				end
				a_stream.set_blocking_io (False)
			end
			l_input_buffer.set_count (l_input_buffer.count + a_stream.last_read)
			total_bytes_read := total_bytes_read + a_stream.last_read
			if l_input_buffer.count = l_input_buffer.capacity then
				if current_input_buffer.right = current_output_buffer then
					-- No more intermediate storage, must empty a buffer to S3 first
					number_of_output_buffer_overflows := number_of_output_buffer_overflows + 1
					if verbose > 1 then
						fd_stderr.put_line ("No more buffer space, force flushing to S3")
					end
					flush_output_buffer
				end
				if verbose > 1 then
					fd_stderr.put_line (once "Moving to next input buffer")
				end
					check
						circular_buffer: attached current_input_buffer.right
					end
				if attached current_input_buffer.right as right_buffer then
					current_input_buffer := right_buffer
				end
				current_input_buffer.item.set_count (0)
			end

			write_output_buffer
		end


feature {NONE} -- Implementation

	ring_buffer: DS_LINKABLE [S3_BUFFER]

	current_input_buffer: like ring_buffer

	current_output_buffer: like ring_buffer

	output_bytes_position: INTEGER

	display_waiting: BOOLEAN

	open_s3
			-- Initiate part upload.
			-- If multipart upload has not yet started, start it.
		require
			not_open: not s3.is_open
		do
			assert_multipart_upload_started
			s3.begin_part_upload (upload_id, key, current_output_buffer.item.count, current_output_buffer.item.sha256.digest_as_string)
			if verbose > 1 then
				if attached s3.parts as parts then
					fd_stderr.put_line ("Part " + (parts.count + 1).out + " upload started.")
				end
			end
		ensure
			s3_open: s3.is_open
		end

	assert_multipart_upload_started
			-- Make sure we have an upload_id.
		do
			if not uploading then
				if verbose > 1 then
					fd_stderr.put_line ("Initiating multipart upload.")
				end
				upload_id := s3.multipart_upload_id (key)
				if not s3.is_response_ok and then s3.response_code >= 500 then
					-- Retry once
					sleep (1)
					upload_id := s3.multipart_upload_id (key)
				end
				if not s3.is_response_ok then
					fd_stderr.put_line ("Failed to initiate multi-part upload.")
					if verbose > 0 then
						if attached s3.body as body then
							fd_stderr.put (body.as_string)
						end
					end
					exit_with_failure
				end

				if verbose > 1 then
					fd_stderr.put_line ("Multipart upload initiated.")
				end
			end
		ensure
			upload_id_set: not upload_id.is_empty
			upload_started: uploading
		end

	write_output_buffer
			-- Write as much of the output buffer to S3 as network will
			-- accept. If entire buffer could be written, finish upload
			-- of part, and move output buffer pointer to next one in the
			-- ring.
			-- Note that in case of restart, `total_bytes_written' might
			-- actually have become smaller.
		local
			output_buffer: S3_BUFFER
			bytes_to_write: INTEGER
		do
			-- We can only write if we have a completed input buffer,
			-- because we must know the entire size of the part upload in
			-- advance.
			if current_output_buffer /= current_input_buffer then

				-- Write as much as possible without blocking
				output_buffer := current_output_buffer.item
				bytes_to_write := output_buffer.count - output_bytes_position
				if bytes_to_write > 0 then
					if not s3.is_open then
						open_s3
					end
					do_write_output_buffer
					display_waiting := true

					if output_bytes_position = output_buffer.count then
						part_finished
						next_output_buffer
					end
				end
			else
				-- Else we need to wait for more input
				number_of_output_buffer_underflows := number_of_output_buffer_underflows + 1
				if verbose > 1 and then display_waiting then
					fd_stderr.put_line ("Nothing to write to S3, waiting for more input")
					display_waiting := false
				end
			end
		end

	do_write_output_buffer
			-- Single write from output buffer to S3.
		require
			open: s3.is_open
			something_to_write: current_output_buffer.item.count > output_bytes_position
			not_reading_and_writing_to_same_buffer: current_output_buffer /= current_input_buffer
		local
			l_output_buffer: S3_BUFFER
			l_bytes_to_write: INTEGER
			l_message: STRING
		do
			l_output_buffer := current_output_buffer.item
			l_bytes_to_write := l_output_buffer.count - output_bytes_position
			if attached {EPX_TEXT_IO_STREAM} s3.http as l_http then
				l_http.put_buffer (l_output_buffer, output_bytes_position, l_bytes_to_write)
				if l_http.errno.is_ok then
					output_bytes_position := output_bytes_position + l_http.last_written
					total_bytes_written := total_bytes_written + l_http.last_written
					something_written := true
				else
					-- S3 failure, restart part
					l_message := l_http.errno.message
					number_of_s3_retries := number_of_s3_retries + 1
					if verbose > 0 then
						if attached s3.parts as parts then
							fd_stderr.put_line ("Part " + (parts.count + 1).out + " upload failed, retrying.")
							fd_stderr.put_line (l_message)
						end
					end
					s3.close
					total_bytes_written := total_bytes_written - output_bytes_position
					output_bytes_position := 0
					open_s3
					if number_of_s3_retries <= s3.max_retries then
						do_write_output_buffer
					end
				end
			end
		end

	flush_output_buffer
			-- Write entire contents of the current output buffer to S3, finish part,
			-- and move output buffer pointer to next buffer.
		require
			not_reading_and_writing_to_same_buffer: current_output_buffer /= current_input_buffer
		local
			output_buffer: S3_BUFFER
		do
			if verbose > 1 then
				fd_stderr.put_line (once "Flushing output buffer to S3")
			end
			if not s3.is_open then
				open_s3
			end
			from
				output_buffer := current_output_buffer.item
			until
				number_of_s3_retries > s3.max_retries or else
				output_bytes_position = output_buffer.count
			loop
				do_write_output_buffer
			end
			display_waiting := true
			part_finished
			next_output_buffer
		ensure
			entire_buffer_written: output_bytes_position = 0 and current_output_buffer /= old current_output_buffer
			total_bytes_written_increased: total_bytes_written = old total_bytes_written + (old current_output_buffer.item.count - old output_bytes_position)
			output_buffer_moved: current_output_buffer /= old current_output_buffer
		end

	part_finished
			-- Part upload finished.
		require
			open: s3.is_open
		do
			s3.end_part_upload
			if s3.is_response_ok then
				if verbose > 1 then
					if attached s3.parts as parts then
						fd_stderr.put_line ("Part " + parts.count.out + " uploaded.")
					end
				end
			else
				if attached s3.body as body then
					fd_stderr.put_line (body.as_string)
				end
				exit_with_failure
			end
		ensure
			closed: s3.is_response_ok implies not s3.is_open
		end

	next_output_buffer
			-- Move output buffer to next buffer in ring.
		do
			if verbose > 1 then
				fd_stderr.put_line (once "Moving to next output buffer")
			end
				check
					right_buffer_exists: attached current_output_buffer.right
				end
			if attached current_output_buffer.right as right_buffer then
				current_output_buffer := right_buffer
			end
			output_bytes_position := 0
		ensure
			output_bytes_position_reset: output_bytes_position = 0
			output_buffer_moved_forward: current_output_buffer = old current_output_buffer.right
		end


invariant

	s3_not_void: s3 /= Void
	total_bytes_read_not_negative: total_bytes_read >= 0
	total_bytes_written_not_negative: total_bytes_written >= 0
	cannot_write_more_than_read: total_bytes_written <= total_bytes_read
	ring_buffer_not_void: ring_buffer /= Void
	current_input_buffer_not_void: current_input_buffer /= Void
	current_output_buffer_not_void: current_output_buffer /= Void
	output_bytes_position_in_range: output_bytes_position <=	current_output_buffer.item.count
	not_reading_and_writing_to_same_buffer: current_input_buffer /= current_output_buffer or else output_bytes_position = 0

end
