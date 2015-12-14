note

	description:

		"Default AWS access keys"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2015, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_ACCESS_KEY


feature -- Access

	access_key_id: STRING
			-- AWS access key if available, else empty string;
			-- Tries to determine this first from an environment variable,
			-- secondly it looks at ~/.aws/credentials.
		local
			env: EPX_ENV_VAR
		once
			create env.make ("AWS_ACCESS_KEY_ID")
			if not env.is_set then
				create env.make ("S3_ACCESS_KEY_ID")
			end
			Result := env.value
			if Result.is_empty then
				Result := parse_aws_credentials.access_key_id
			end
		ensure
			not_void: Result /= Void
		end

	secret_access_key: detachable STRING
			-- AWS secret access key, if available, else empty string;
			-- Tries to determine this first from an environment variable,
			-- secondly it looks at ~/.aws/credentials.
		local
			env: STDC_ENV_VAR
		once
			create env.make ("AWS_SECRET_ACCESS_KEY")
			if not env.is_set then
				create env.make ("S3_SECRET_ACCESS_KEY")
			end
			Result := env.value
			if Result.is_empty then
				Result := parse_aws_credentials.secret_access_key
			end
		ensure
			not_void: Result /= Void
		end


feature {NONE} -- Parse ~/.aws/credentials

	parse_aws_credentials: TUPLE [access_key_id: STRING; secret_access_key: STRING]
		local
			aws_credentials: EPX_PATH
			file_system: EPX_FILE_SYSTEM
			file: STDC_TEXT_FILE
			sh: EPX_STRING_HELPER
			ar: ARRAY [STRING]
			key: STRING
		once
			Result := ["", ""]
			create aws_credentials.make_expand ("~/.aws/credentials")
			create file_system
			if file_system.is_readable (aws_credentials) then
				create sh
				create file.open_read (aws_credentials)
				from
					file.read_line
				until
					file.end_of_input
				loop
					ar := sh.split_on (file.last_string, '=')
					if ar.count = 2 then
						key := ar.item (ar.lower)
						sh.trim (key)
						if key ~ "aws_access_key_id" then
							Result.access_key_id := ar.item (ar.upper)
							sh.trim (Result.access_key_id)
						elseif key ~ "aws_secret_access_key" then
							Result.secret_access_key := ar.item (ar.upper)
							sh.trim (Result.secret_access_key)
						end
					end
					file.read_line
				end
			end
		end

end
