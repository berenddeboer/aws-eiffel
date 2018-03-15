note

	description:

		"AWS CloudWatch validations"

	library: "Amazon CloudWatch library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2018, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_CLOUDWATCH_CHECKS



feature -- Status

	is_valid_name_space (a_name_space: READABLE_STRING_GENERAL): BOOLEAN
		do
			Result := attached a_name_space as n and then not n.is_empty
		end


end
