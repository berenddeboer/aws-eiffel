note

	description:

		"Interface to Amazon EC2"

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2013, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_EC2


inherit

	AWS_BASE

	UT_URL_ENCODING
		export
			{NONE} all
		end


create

	make


feature {NONE} -- Initialisation

	make (an_access_key_id, a_secret_access_key, a_region: READABLE_STRING_GENERAL)
		require
			access_key_has_correct_length: an_access_key_id /= Void and then an_access_key_id.count = 20
			secret_key_has_correct_length: a_secret_access_key /= Void and then a_secret_access_key.count = 40
			a_region_not_empty: a_region /= Void and then not a_region.is_empty
		do
			-- is_secure_connection := True
			make_aws_base ("ec2." + a_region.out + ".amazonaws.com", an_access_key_id, a_secret_access_key)
		end


feature -- Methods

	version: STRING = "2013-02-01"

end
