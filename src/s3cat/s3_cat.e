note

	description:

		"Output object from s3 to stdout"

	library: "s3 tools"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008, Berend de Boer"
	license: "MIT License (see LICENSE)"
	date: "$Date$"
	revision: "$Revision$"


class

	S3_CAT


inherit

	S3_TOOL


create

	make,
	make_no_rescue


feature {NONE} -- Initialize

	make_no_rescue
		local
			l_output: EPX_FILE_DESCRIPTOR
		do
			parse_arguments
			if attached bucket.parameter as l_bucket and then attached key.parameter as l_key then
				if file_option.occurrences > 0 and then attached file_option.parameter as l_file_name then
					create l_output.create_write (l_file_name)
				else
					l_output := fd_stdout
				end
				copy_s3_to_stdout (region, l_bucket, l_key, l_output)
			end
		end


feature -- Reading

	copy_s3_to_stdout (a_region, a_bucket, a_key: READABLE_STRING_8; an_output: EPX_FILE_DESCRIPTOR)
		require
			output_open: an_output.is_open
		local
			s3: S3_CLIENT
			reading_parts: BOOLEAN
			part: INTEGER
			start: STDC_TIME
			--total_bytes_received: INTEGER_64
			bytes_received: INTEGER_64
			buffer: STDC_BUFFER
			s: STRING
		do
			create buffer.allocate (buffer_size)
			create s3.make (a_region, a_bucket)
			-- Cannot reuse, because we expect an eof in the append code below
			--s3.set_reuse_connection
			s3.set_continue_on_error
			create start.make_from_now
			if attached bucket.parameter as l_bucket and then attached key.parameter as l_key then
				s3.retrieve_object_header_with_retry (l_key)

				if s3.response_code = 404 then
					if verbose.occurrences > 2 then
						print_http_response_header (s3)
					end
					if verbose.occurrences > 1 then
						fd_stderr.put_line (once "Exact name not found, checking for part 0.")
					end
					-- Exact name not found, might be a prefix, so check if
					-- part 0 exists.
					s3.retrieve_object_header_with_retry (l_key + format(once ":$020i", <<integer_cell (part)>>))
					reading_parts := True
				end

				print_http_response_header (s3)

				if s3.response_code = 200 then
					if attached s3.response as l_response and then attached l_response.header.content_length as l_content_length then
						if verbose.occurrences > 0 then
							if attached s3.last_uri as l_uri then
								fd_stderr.put_string (once "Downloading " + l_uri)
								if file_option.occurrences > 0 and then attached file_option.parameter as l_file_name then
									fd_stderr.put_string (once " to " + l_file_name)
								end
							end
							fd_stderr.put_line (" (" + l_content_length.length.out + " bytes)")
						end
						if attached l_response.text_body as l_text_body then
							an_output.put_string (l_text_body.as_string)
						end
						if attached s3.http as l_http then
							read_object (l_http, buffer, l_content_length.length, an_output)
						end
						bytes_received := bytes_received + l_content_length.length
						print_download_speed (bytes_received, start)
					end
					if reading_parts then
						from
							part := 1
						until
							s3.response_code = 404
						loop
							s3.retrieve_object_header_with_retry (l_key + format(once ":$020i", <<integer_cell (part)>>))
							print_http_response_header (s3)
							if s3.response_code = 200 then
								if attached s3.response as l_response and then attached l_response.header.content_length as l_content_length then
									if verbose.occurrences > 0 then
										if attached s3.last_uri as l_uri then
											fd_stderr.put_line (once "Downloading " + l_uri)
										end
									end
									if attached l_response.text_body as l_text_body then
										an_output.put_string (l_text_body.as_string)
									end
									if attached s3.http as l_http then
										read_object (l_http, buffer, l_content_length.length, an_output)
									end
									bytes_received := bytes_received + l_content_length.length
								end
								print_download_speed (bytes_received, start)
								part := part + 1
							end
						end
					end
				elseif s3.response_code = 403 then
					fd_stderr.put_line ("Invalid credentials for " + l_bucket + "/" + l_key)
					exit_with_failure
				elseif s3.response_code = 404 then
					fd_stderr.put_line ("No object named " + l_bucket + "/" + l_key)
					exit_with_failure
				else
					fd_stderr.put_line ("Server response: " + s3.response_code.out)
					exit_with_failure
				end
			end
		end


feature -- Access

	buffer_size: INTEGER = 16384

	key: AP_STRING_OPTION

	file_option: AP_STRING_OPTION


feature {NONE} -- Argument parsing

	parse_arguments
		local
			parser: AP_PARSER
		do
			parser := new_default_parser (once "s3cat 1.1 (c) by Berend de Boer <berend@pobox.com>%NStream s3 object to stand otuput.")
			create key.make ('k', "key")
			key.set_description ("Key name.")
			key.enable_mandatory
			parser.options.force_last (key)
			create file_option.make ('f', "file")
			file_option.set_description ("Write to file instead of stdout.")
			parser.options.force_last (file_option)
			do_parse_arguments (parser)
		end


feature {NONE} -- Implementation

	print_http_response_header (s3: S3_CLIENT)
		require
			s3_not_void: s3 /= Void
		do
			if verbose.occurrences > 1 then
				fd_stderr.put_string (s3.response_code.out)
				fd_stderr.put_character (' ')
				fd_stderr.put_line (s3.response_phrase)
				if attached s3.response as l_response then
					fd_stderr.put_line (l_response.header.as_string)
				end
			end
		end

	print_download_speed (bytes_received: INTEGER_64; start_time: STDC_TIME)
		local
			now: STDC_TIME
			duration: INTEGER
			per_sec: DOUBLE
			unit: STRING
		do
			if verbose.occurrences > 0 then
				create now.make_from_now
				duration := now.value - start_time.value
				if duration = 0 then
					duration := 1
				end
				per_sec := bytes_received / duration
				if per_sec > 1024 then
					per_sec := per_sec / 1024
					unit := once "KB"
				else
					unit := once "bytes"
				end
				fd_stderr.put_line (format (once "$.2f $s/s", <<double_cell (per_sec), unit>>))
			end
		end

	read_object (in: EPX_TEXT_IO_STREAM; buffer: STDC_BUFFER; an_object_size: INTEGER_64; an_output: EPX_FILE_DESCRIPTOR)
			-- Read a single object of size `an_object_size'.
		require
			bytes_to_read_not_negative: an_object_size >= 0
			output_open: an_output.is_open
		local
			bytes_to_read: INTEGER_64
			max_to_read: INTEGER
		do
			from
				bytes_to_read := an_object_size
				if bytes_to_read > buffer.capacity then
					max_to_read := buffer.capacity
				else
					max_to_read := bytes_to_read.to_integer
				end
				in.read_buffer (buffer, 0, max_to_read)
			until
				bytes_to_read = 0 or else
				in.end_of_input or else
				in.errno.is_not_ok
			loop
				an_output.put_buffer (buffer, 0, in.last_read)
				bytes_to_read := bytes_to_read - in.last_read
				if bytes_to_read > buffer.capacity then
					max_to_read := buffer.capacity
				else
					max_to_read := bytes_to_read.to_integer
				end
				in.read_buffer (buffer, 0, max_to_read)
			variant
				bytes_to_read
			end
		end

end
