note

	description:

		"Gives access to AWS access keys. Access keys are derived environment variables, ~/.aws/credentials (only suports the default profile for now), or the IAM role in that order. Override the access kes by setting cached_access_key and cached_secret_access_key."

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2015, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_ACCESS_KEY


inherit {NONE}

	CAPI_TIME
		rename
			-- Give a process easy access to the current time
			posix_time as current_time
		end


feature -- Access

	access_key_id: READABLE_STRING_8
			-- AWS access key if available, else empty string;
			-- Tries to determine this first from an environment variable,
			-- secondly it looks at ~/.aws/credentials, and finally at
			-- it checks if an IAM role has been set.
			-- Access Key IDs are a 20-character, alphanumeric sequence.
		do
			if are_credentials_expired then
				refresh_iam_role_credentials
			end
			Result := cached_access_key_id
		ensure
			not_void: Result /= Void
			valid: Result.is_empty or else Result.count = 20
		end

	secret_access_key: READABLE_STRING_8
			-- AWS secret access key, if available, else empty string;
			-- Tries to determine this first from an environment variable,
			-- secondly it looks at ~/.aws/credentials, finally it checks IAM role.
		do
			if are_credentials_expired then
				refresh_iam_role_credentials
			end
			Result := cached_secret_access_key
		ensure
			not_void: Result /= Void
			valid: Result.is_empty or else Result.count = 40
		end


feature {NONE} -- Parse ~/.aws/credentials

	parse_aws_credentials: TUPLE [access_key_id: STRING; secret_access_key: STRING]
			-- All settings in the default profile as key value pair
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


feature -- Cached values that a client may wish to override in certain circumstances

	cached_access_key_id: STRING
		once
			Result := static_access_key_id.out
		end

	cached_secret_access_key: STRING
		once
			Result := static_secret_access_key.out
		end


feature {NONE} -- Cached values

	static_access_key_id: READABLE_STRING_GENERAL
			-- AWS access key if available, else empty string;
			-- Tries to determine this first from an environment variable,
			-- secondly it looks at ~/.aws/credentials, and finally at
			-- it checks if an IAM role has been set.
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

	static_secret_access_key: READABLE_STRING_GENERAL
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

	iam_role_token: STRING
			-- IAM role token if any;
			-- Set by `refresh_iam_role_credentials'
		once
			create Result.make_empty
		end

	iam_role_key_expiration: EPX_TIME
			-- When IAM role temporary key will expire
		once
			create Result.make_from_unix_time (0)
		end

	are_credentials_expired: BOOLEAN
		do
			Result :=
				static_access_key_id.is_empty and then
				static_secret_access_key.is_empty
			if Result then
				if iam_role_key_expiration.value > 0 then
					Result :=
						iam_role_key_expiration.value < current_time
				else
					Result := True
				end
			end
		end

	refresh_iam_role_credentials
			-- Read IAM role credentials and set `cached_access_key_id'
			-- `cached_secret_access_key_id', `iam_role_token' and
			-- 'iam_role_key_expiration'.
		local
			metadata: AWS_METADATA
			role: READABLE_STRING_GENERAL
			jo: JSON_OBJECT
		do
			create metadata
			role := metadata.role_name
			jo := metadata.security_credentials (role)
			if attached jo as o and then
				attached {JSON_STRING} o.item ("AccessKeyId") as access_key and then
				attached {JSON_STRING} o.item ("SecretAccessKey") as secret_key and then
				attached {JSON_STRING} o.item ("Token") as token and then
				attached {JSON_STRING} o.item ("Expiration") as expiration then
				cached_access_key_id.wipe_out
				cached_access_key_id.append_string (access_key.unescaped_string_8)
				cached_secret_access_key.wipe_out
				cached_secret_access_key.append_string (secret_key.unescaped_string_8)
				iam_role_key_expiration.make_from_iso_8601 (expiration.unescaped_string_8)
				iam_role_token.wipe_out
				iam_role_token.append_string (token.unescaped_string_8)
			end
		end

end
