indexing

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

	S3_ACCESS_KEY

	EPX_CURRENT_PROCESS

	ST_FORMATTING_ROUTINES
		export
			{NONE} all
		end

create

	make,
	make_no_rescue


feature {NONE} -- Initialize

	make is
		do
			make_no_rescue
		rescue
			if exceptions.is_developer_exception then
				fd_stderr.put_line (exceptions.developer_exception_name)
			else
				fd_stderr.put_string (once "Exception code: ")
				fd_stderr.put_line (exceptions.exception.out)
			end
			exit_with_failure
		end

	make_no_rescue is
		local
			s3: S3_CLIENT
			reading_parts: BOOLEAN
			part: INTEGER
			start: STDC_TIME
			--total_bytes_received: INTEGER_64
			bytes_received: INTEGER_64
			buffer: STDC_BUFFER
		do
			parse_arguments
			create buffer.allocate (buffer_size)
			create s3.make (access_key_id, secret_access_key)
			-- Cannot reuse, because we expect an eof in the append code below
			--s3.set_reuse_connection
			s3.set_continue_on_error
			create start.make_from_now
			s3.retrieve_object_header_with_retry (bucket.parameter, key.parameter)
			--s3.read_response
			if s3.response_code = 404 then
				if verbose.occurrences > 2 then
					print_http_response_header (s3)
				end
				-- Exact name not found, might be a prefix, so check if
				-- part 0 exists.
				s3.retrieve_object_header_with_retry (bucket.parameter, key.parameter + format(once ":$020i", <<integer_cell (part)>>))
				reading_parts := True
			end
			print_http_response_header (s3)
			if s3.response_code = 200 then
				if verbose.occurrences > 0 then
					fd_stderr.put_string (once "Downloading " + s3.last_uri)
					fd_stderr.put_line (" (" + s3.response.header.content_length.length.out + " bytes)")
				end
				fd_stdout.put_string (s3.response.text_body.as_string)
				--fd_stdout.append (s3.http)
				read_object (s3.http, buffer, s3.response.header.content_length.length)
				bytes_received := bytes_received + s3.response.header.content_length.length
				print_download_speed (bytes_received, start)
				if reading_parts then
					from
						part := 1
					until
						s3.response_code = 404
					loop
						s3.retrieve_object_header_with_retry (bucket.parameter, key.parameter + format(once ":$020i", <<integer_cell (part)>>))
						print_http_response_header (s3)
						if s3.response_code = 200 then
							if verbose.occurrences > 0 then
								fd_stderr.put_line (once "Downloading " + s3.last_uri)
							end
							fd_stdout.put_string (s3.response.text_body.as_string)
							read_object (s3.http, buffer, s3.response.header.content_length.length)
							bytes_received := bytes_received + s3.response.header.content_length.length
							print_download_speed (bytes_received, start)
							part := part + 1
						end
					end
				end
			elseif s3.response_code = 403 then
				fd_stderr.put_line ("Invalid credentials for " + bucket.parameter + "/" + key.parameter)
				exit_with_failure
			else
				fd_stderr.put_line ("Server response: " + s3.response_code.out)
				fd_stderr.put_line ("No object named " + bucket.parameter + "/" + key.parameter)
				exit_with_failure
			end
		end


feature -- Access

	buffer_size: INTEGER is 16384

	bucket: AP_STRING_OPTION

	key: AP_STRING_OPTION

	verbose: AP_FLAG


feature {NONE} -- Argument parsing

	parse_arguments is
		local
			parser: AP_PARSER
		do
			create parser.make
			parser.set_application_description (once "Output contents of a given S3 object to standard output.")
			parser.set_parameters_description (once "")
			create bucket.make ('b', "bucket")
			bucket.set_description ("Bucket name.")
			bucket.enable_mandatory
			parser.options.force_last (bucket)
			create key.make ('k', "key")
			key.set_description ("Key name.")
			key.enable_mandatory
			parser.options.force_last (key)
			create verbose.make ('v', "verbose")
			verbose.set_description ("Verbose output like progress.")
			parser.options.force_last (verbose)

			parser.parse_arguments
			if access_key_id.is_empty then
				fd_stderr.put_line ("Environment variable S3_ACCESS_KEY_ID not set. It should contain your Amazon access key.")
				parser.help_option.display_usage (parser)
			end
			if secret_access_key.is_empty then
				fd_stderr.put_line ("Environment variable S3_SECRET_ACCESS_KEY not set. It should contain your Amazon secret access key.")
				parser.help_option.display_usage (parser)
			end
		end


feature {NONE} -- Implementation

	print_http_response_header (s3: S3_CLIENT) is
		require
			s3_not_void: s3 /= Void
		do
			if verbose.occurrences > 1 then
				fd_stderr.put_string (s3.response_code.out)
				fd_stderr.put_character (' ')
				fd_stderr.put_line (s3.response_phrase)
				fd_stderr.put_line (s3.response.header.as_string)
			end
		end

	print_download_speed (bytes_received: INTEGER_64; start_time: STDC_TIME) is
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

	read_object (in: EPX_TEXT_IO_STREAM; buffer: STDC_BUFFER; an_object_size: INTEGER_64) is
			-- Read a single object of size `an_object_size'.
		require
			in_not_void: in /= Void
			buffer_not_void: buffer /= Void
			bytes_to_read_not_negative: a_bytes_to_read >= 0
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
			variant
				bytes_to_read
			until
				bytes_to_read = 0 or else
				in.end_of_input or else
				in.errno.is_not_ok
			loop
				fd_stdout.put_buffer (buffer, 0, in.last_read)
				bytes_to_read := bytes_to_read - in.last_read
				if bytes_to_read > buffer.capacity then
					max_to_read := buffer.capacity
				else
					max_to_read := bytes_to_read.to_integer
				end
				in.read_buffer (buffer, 0, max_to_read)
			end
		end

end
