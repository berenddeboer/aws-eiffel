note

	description:

		"Default AWS access keys"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_ACCESS_KEY


feature -- Access

	access_key_id: STRING
			-- AWS access key from environment variable, if available;
			-- Empty string otherwise.
		local
			env: EPX_ENV_VAR
		once
			create env.make (once "AWS_ACCESS_KEY_ID")
			if not env.is_set then
				create env.make (once "S3_ACCESS_KEY_ID")
			end
			Result := env.value
		ensure
			not_void: Result /= Void
		end

	secret_access_key: STRING
			-- AWS secret access key from environment variable, if available;
			-- Empty string otherwise.
		local
			env: STDC_ENV_VAR
		once
			create env.make (once "AWS_SECRET_ACCESS_KEY")
			if not env.is_set then
				create env.make (once "S3_SECRET_ACCESS_KEY")
			end
			Result := env.value
		ensure
			not_void: Result /= Void
		end


end
