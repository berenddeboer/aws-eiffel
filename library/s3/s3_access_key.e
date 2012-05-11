indexing

	description:

		"Default access keys"

	library: "s3 library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008, Berend de Boer"
	license: "MIT License (see LICENSE)"
	date: "$Date$"
	revision: "$Revision$"


class

	S3_ACCESS_KEY


feature -- Access

	access_key_id: STRING is
		local
			env: STDC_ENV_VAR
		once
			create env.make (once "S3_ACCESS_KEY_ID")
			Result := env.value
		end

	secret_access_key: STRING is
		local
			env: STDC_ENV_VAR
		once
			create env.make (once "S3_SECRET_ACCESS_KEY")
			Result := env.value
		end


end
