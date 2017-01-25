note

	description:

		"S3 library"

	library: "s3 library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	S3_VERBOSE_ROUTINES


inherit

	ST_FORMATTING_ROUTINES
		export
			{NONE} all
		end


feature -- Helpers

	formatted_upload_speed (bytes_send: INTEGER_64; start_time: STDC_TIME): STRING
			-- Nicely format average speed.
		require
			bytes_send_not_negative: bytes_send >= 0
			start_time_not_void: start_time /= Void
		local
			now: STDC_TIME
			duration: INTEGER
			per_sec: DOUBLE
			unit: STRING
		do
			create now.make_from_now
			duration := now.value - start_time.value
			if duration = 0 then
				duration := 1
			end
			per_sec := bytes_send / duration
			if per_sec >= 1024 * 1024 then
				per_sec := per_sec / (1024 * 1024)
				unit := once "MB"
			elseif per_sec >= 1024 then
				per_sec := per_sec / 1024
				unit := once "KB"
				else
					unit := once "bytes"
			end
			Result := format (once "$.2f $s/s", <<double_cell (per_sec), unit>>)
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end

end
