note

	description:

		"EPX_PARTIAL_BUFFER with SHA256."

	library: "s3 tools"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2019, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	S3_BUFFER


inherit

	EPX_PARTIAL_BUFFER
		redefine
			allocate,
			set_count
		end


create

	allocate


feature {NONE} -- Initialisation

	allocate (a_capacity: INTEGER)
		do
			precursor (a_capacity)
			create sha256.make
		end


feature -- Change

	set_count (a_count: INTEGER)
		local
			l_old_count: INTEGER
			i: INTEGER
		do
			l_old_count := count
			precursor (a_count)
			if a_count = 0 then
				sha256.reset
			else
				from
					i := l_old_count
				until
					i >= a_count
				loop
					sha256.update_from_byte (peek_byte (i))
					i := i + 1
				end
			end
		end


feature -- Access

	sha256: SHA256

end
