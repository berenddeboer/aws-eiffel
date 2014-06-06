note

	description:

		"Stream stdout to S3 bucket"

	library: "s3 tools"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2011, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	S3_STORE


inherit

	S3_TOOL


create

	make,
	make_no_rescue


feature {NONE} -- Initialize

	make_no_rescue
			-- Initialize. and run.
		local
			signal: STDC_SIGNAL
		do
			parse_arguments
			create signal.make (SIGPIPE)
			signal.set_ignore_action
			signal.apply
			copy_input_to_s3
			if verbose.occurrences > 0 then
				--fd_stderr.put_line (formatted_upload_speed (bytes_sent, start))
			end
		end


feature -- Access

	buffer_size: INTEGER = 16384


feature {NONE} -- Argument parsing

	key: AP_STRING_OPTION

	part_size: AP_INTEGER_OPTION

	nonblocking_io: AP_FLAG

	parse_arguments
		local
			parser: AP_PARSER
		do
			parser := new_default_parser (once "s3store 1.0 (c) by Berend de Boer <berend@pobox.com>%NStream standard input to a given S3 object.")
			create key.make ('k', "key")
			key.set_description ("Key name.")
			key.enable_mandatory
			parser.options.force_last (key)
			create part_size.make ('p', "part-size")
			part_size.set_description ("Part size in MB; smaller parts mean writing to S3 starts earlier.")
			parser.options.force_last (part_size)
			create nonblocking_io.make ('n', "non-blocking-io")
			nonblocking_io.set_description ("If your S3 write speed is slower than your input speed, non-blocking i/o might give you better performance.")
			parser.options.force_last (nonblocking_io)
			do_parse_arguments (parser)
		end


feature -- Writing

	copy_input_to_s3
			-- Read from stdin, dump to bucket.
		local
			writer: S3_WRITER
			r: STRING
			start: EPX_TIME
			last_speed_update: INTEGER
			now: INTEGER
		do
			if region.was_found then
				r := region.parameter
			end
			create writer.make (access_key_id, secret_access_key, r, bucket.parameter, key.parameter, verbose.occurrences)
			writer.set_verbose (verbose.occurrences)
			if part_size.was_found then
				writer.set_part_size (part_size.parameter * 1024 * 1024)
			end
			if nonblocking_io.occurrences > 0 then
				fd_stdin.set_blocking_io (False)
			end
			create start.make_from_now
			last_speed_update := current_time
			from
			until
				fd_stdin.end_of_input
			loop
				writer.write (fd_stdin)
				if verbose.occurrences > 0 then
					now := current_time
					if now - last_speed_update > 3 then
						fd_stderr.put_line (formatted_upload_speed (writer.total_bytes_written, start))
						last_speed_update := current_time
					end
				end
			end
			writer.close
				check
					as_much_written_as_read: writer.total_bytes_read = writer.total_bytes_written
				end
			if verbose.occurrences > 0 then
				fd_stderr.put_line (formatted_upload_speed (writer.total_bytes_written, start))
				fd_stderr.put_line ("Finished, wrote a total of " + writer.total_bytes_written.out + " bytes.")
				fd_stderr.put_line ("Statistics:")
				fd_stderr.put_line ("  non-blocking reads      : " + writer.number_of_nonblocking_reads.out)
				fd_stderr.put_line ("  blocking reads          : " + writer.number_of_blocking_reads.out)
				fd_stderr.put_line ("  output buffer underflows: " + writer.number_of_output_buffer_underflows.out)
				fd_stderr.put_line ("  output buffer overflows : " + writer.number_of_output_buffer_overflows.out)
				fd_stderr.put_line ("  s3 retries              : " + writer.number_of_s3_retries.out)
			end
		end


end
