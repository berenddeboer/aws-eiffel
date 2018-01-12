note

	description:

		"Access to instance meta data"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2016, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_METADATA


feature -- Access

	instance_id: READABLE_STRING_GENERAL
			-- Instance id
		local
			process: EPX_CURRENT_PROCESS
		once
			Result := value ("/latest/meta-data/instance-id/")
			if Result.is_empty then
				-- this should exist, so retry once.
				create process
				process.sleep (2)
				Result := value ("/latest/meta-data/instance-id/")
			end
		end

	role_name: READABLE_STRING_GENERAL
			-- Optional IAM role
		once
			Result := value ("/latest/meta-data/iam/security-credentials/")
		end

	availability_zone: READABLE_STRING_GENERAL
			-- The Availability Zone in which the instance launched.
		once
			Result := value ("/latest/meta-data/placement/availability-zone")
		end

	region: READABLE_STRING_GENERAL
			-- Region determined from `availability_zone';
			-- Will fail if amazon gets more than 26 availability zones;
			-- Returns empty string if data could not be accessed.
		local
			s: STRING
		once
			s := value ("/latest/meta-data/placement/availability-zone").out
			s.remove_tail (1)
			Result := s
		end

	security_credentials (a_role: READABLE_STRING_GENERAL): detachable JSON_OBJECT
			-- Security credentials for a given role
		require
			role_not_empty: not a_role.is_empty
		local
			json: READABLE_STRING_GENERAL
			parser: JSON_PARSER
		do
			json := value ("/latest/meta-data/iam/security-credentials/" + a_role)
			create parser.make_with_string (json.out)
			parser.parse_content
			if parser.is_valid and then
				attached parser.parsed_json_value as jv and then
				attached {JSON_OBJECT} jv as j_object then
				Result := j_object
			end
		end


feature {NONE} -- Implementation

	value (a_path: READABLE_STRING_GENERAL): READABLE_STRING_GENERAL
			-- Return the value for the given `a_path', or the empty
			-- string if an error occurred.
		local
			client: EPX_HTTP_11_CLIENT
		do
			create client.make ("169.254.169.254")
			client.set_continue_on_error
			client.get (a_path)
			-- TODO: retry in case of failure?
			if client.is_response_ok then
				client.read_response_with_redirect
				if client.is_response_ok then
					debug ("aws_metadata")
						print ("Retrieved meta data " + a_path + ", response code: " + client.response_code.out + "%N")
					end
					if attached client.response as a_response then
						Result := a_response.body.as_string
					else
						Result := ""
					end
				else
					debug ("aws_metadata")
						print ("Failure to retrieve meta data " + a_path + ", response code: " + client.response_code.out + "%N")
					end
					Result := ""
				end
			else
				Result := ""
			end
		end

end
