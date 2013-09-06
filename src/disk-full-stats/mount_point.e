note

	description:

		"Description of a single mount point"

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2013, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	MOUNT_POINT


inherit

	EPX_FILE_SYSTEM


inherit {NONE}

	KL_IMPORTED_STRING_ROUTINES

	STDC_BASE

	SAPI_STAT


create

	make


feature {NONE} -- Initialisation

	make (a_path: READABLE_STRING_8)
		require
			path_not_empty: a_path /= Void and then not a_path.is_empty
		do
			create now.make_from_now
			path := a_path
			create statvfs.allocate_and_clear (posix_statvfs_size)
			safe_call (posix_statvfs (sh.string_to_pointer (path), statvfs.ptr))
			sh.unfreeze_all
			read_last_check
		end



feature -- Commands

	save_check
			-- Save current statistics to be used for next check.
		do
			if not is_directory (cache_directory) then
				make_directory (cache_directory)
			end
			string_to_file (bytes_free.out, cache_file_name)
		end

	read_last_check
		local
			s: STRING
		do
			last_bytes_free := bytes_free
			if is_readable (cache_file_name) then
				s := file_content_as_string (cache_file_name)
				if s.is_integer_64 then
					last_bytes_free := s.to_integer_64
				end
			end
		ensure
			last_bytes_free_not_negative: last_bytes_free >= 0
		end


feature -- Access

	path: READABLE_STRING_8

	file_system_type: READABLE_STRING_8

	cache_directory: STRING = "/var/cache/disk-full-stats/"

	cache_file_name: STRING
			-- File name where cached bytes free are stored
		local
			p: STDC_PATH
		once
			Result := cache_directory.out
			if STRING_.same_string (path, "/") then
				Result.append_string ("root")
			else
				-- TODO: better: replace / by _
				create p.make_from_string (path)
				p.parse (Void)
				Result.append_string (p.basename)
			end
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end

	bytes_free: INTEGER_64
		local
			block_size: INTEGER_64
			free_blocks: INTEGER_64
		do
			block_size := posix_statvfs_f_bsize (statvfs.ptr)
			free_blocks := posix_statvfs_f_bfree (statvfs.ptr)
			-- This probably doesn't work well on big file systems...
			Result := block_size * free_blocks
		ensure
			not_negative: Result >= 0
		end

	bytes_written: INTEGER_64
			-- Bytes written between last recorded check and now.
			-- Positive if disk is filling up, negative is disk space has
			-- been freed.
		do
			Result := last_bytes_free - bytes_free
		end

	last_bytes_free: INTEGER_64
			-- Bytes free on last recorded check

	seconds_since_last_check: INTEGER
		once
			if is_readable (cache_file_name) then
				Result := now.value - status (cache_file_name).modification_time
			else
				Result := Result.Max_value
			end
		end

	days_to_fill_up: DOUBLE
			-- Number (and fraction) of days till disk fills up,
			-- comparing the currnt disk free and the last disk free
			-- check.
		local
			bytes_per_day: DOUBLE
		do
			Result := max_days
			if bytes_written > 0 then
				bytes_per_day := (seconds_in_day / seconds_since_last_check) * bytes_written
				Result := bytes_free / bytes_per_day
				if Result > max_days then
					Result := max_days
				end
			end
		ensure
			not_negative: Result >= 0
			not_more_than_1_year: Result <= max_days
		end

	max_days: INTEGER = 99
			-- The maximum days to return when disk is never or very
			-- slowly filling up;
			-- Use a small number so graphs look sanish.


feature {NONE} -- Implementation

	now: STDC_TIME

	seconds_in_day: INTEGER = 86400

	statvfs: EPX_BUFFER


invariant

	statvfs_not_void: statvfs /= Void
	path_not_empty: path /= Void and then not path.is_empty
	file_system_type_not_empty: file_system_type /= Void and then not file_system_type.is_empty

end
