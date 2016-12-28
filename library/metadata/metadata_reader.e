note

	description:

		"Access to instance meta data"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2016, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	METADATA_READER


feature -- Access

	instance_id: READABLE_STRING_GENERAL
			-- Instance id
		once
			Result := value ("/latest/meta-data/instance-id/")
		end

	role_name: READABLE_STRING_GENERAL
			-- Instance id
		once
			Result := value ("/latest/meta-data/iam/security-credentials/")
		end

	value (a_path: READABLE_STRING_GENERAL): READABLE_STRING_GENERAL
			-- Return the value for the given `a_path', or the empty
			-- string if an error occurred.
		local
			client: EPX_HTTP_11_CLIENT
		do
			create client.make ("169.254.169.254")
			client.get (a_path)
			client.read_response_with_redirect
			if client.is_response_ok then
				debug ("aws-metadata_reader")
					print ("Retrieved meta data " + a_path + ", response code: " + client.response_code.out + "%N")
				end
				Result := client.response.body.as_string
			else
				debug ("aws-metadata_reader")
					print ("Failure to retrieve meta data " + a_path + ", response code: " + client.response_code.out + "%N")
				end
				Result := ""
			end
		end

end
