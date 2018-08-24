note

	description:

		"Default AWS region"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2015, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_REGION


feature -- Access

	region: READABLE_STRING_8
			-- Default region;
			-- Uses AWS_REGION if set, else tries to read ~/.aws/config,
			-- and if that is not available, read instance metadata.
		local
			env: EPX_ENV_VAR
			metadata: AWS_METADATA
		once
			create env.make ("AWS_REGION")
			Result := env.value
			if Result.is_empty then
				Result := parse_aws_config.region
				if Result.is_empty then
					create metadata
					Result := metadata.region
				end
			end
		ensure
			not_void: Result /= Void
		end


feature {NONE} -- Parse ~/.aws/config

	parse_aws_config: TUPLE [region: STRING]
		local
			aws_config: EPX_PATH
			file_system: EPX_FILE_SYSTEM
			file: STDC_TEXT_FILE
			sh: EPX_STRING_HELPER
			ar: ARRAY [STRING]
			key: STRING
		once
			Result := [""]
			create aws_config.make_expand ("~/.aws/config")
			create file_system
			if file_system.is_readable (aws_config) then
				create sh
				create file.open_read (aws_config)
				from
					file.read_line
				until
					file.end_of_input
				loop
					ar := sh.split_on (file.last_string, '=')
					if ar.count = 2 then
						key := ar.item (ar.lower)
						sh.trim (key)
						if key ~ "region" then
							Result.region := ar.item (ar.upper)
							sh.trim (Result.region)
						end
					end
					file.read_line
				end
			end
		ensure
			region_not_void: Result.region /= Void
		end


end
