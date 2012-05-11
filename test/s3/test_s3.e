indexing

	description:

		"Test S3 library"

	library: "Eiffel S3 library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008, Berend de Boer"
	license: "MIT License (see LICENSE)"
	date: "$Date$"
	revision: "$Revision$"


deferred class

	TEST_S3


inherit

	TS_TEST_CASE


feature -- Tests

	test_get_data is
		local
			s3: S3_CLIENT
			f: STDC_TEXT_FILE
		do
			assert ("Key set", not access_key_id.is_empty)
			assert ("Secret key set", not secret_access_key.is_empty)
			create s3.make (access_key_id, secret_access_key)
			s3.get_object ("ami.drupalfocus.com", key)
			s3.read_response_header
			assert_integers_equal ("Response code", 200, s3.response_code)
			create f.open_write (key)
			f.put_string (s3.response.text_body.as_string)
			f.append (s3.http)
			f.close
		end


feature {NONE} -- Implementation

	key: STRING is "drupalfocus-20080812T22.20.43.manifest.xml"

	access_key_id: STRING is
		local
			env: STDC_ENV_VAR
		once
			create env.make ("AWS_ACCESS_KEY_ID")
			Result := env.value
		end

	secret_access_key: STRING is
		local
			env: STDC_ENV_VAR
		once
			create env.make ("AWS_ACCESS_KEY_SECRET")
			Result := env.value
		end

end
