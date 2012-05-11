note

	description:

		"Base class for AWS services"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_BASE


inherit

	EPX_HTTP_11_CLIENT
		rename
			make as make_http_11_client
		end


feature {NONE} -- Initialiation

	make_aws_base (a_server_name, an_access_key_id, a_secret_access_key: READABLE_STRING_GENERAL)
		require
			access_key_has_correct_length: an_access_key_id /= Void and then an_access_key_id.count = 20
			secret_key_has_correct_length: a_secret_access_key /= Void and then a_secret_access_key.count = 40
		do
			make_http_11_client (a_server_name.out)
			-- make_secure (a_server_name)
			access_key_id := an_access_key_id
			create hasher.make (a_secret_access_key.out, create {EPX_SHA1_CALCULATION}.make)
		end


feature -- Access

	access_key_id: READABLE_STRING_GENERAL
			-- Access Key ID (a 20-character, alphanumeric sequence)


feature {NONE} -- Request signing

	hasher: EPX_HMAC_CALCULATION


invariant

	valid_access_key: access_key_id /= Void and then access_key_id.count = 20
	hasher_not_void: hasher /= Void

end
