note

	description:

		"Base class for utilities that make EC2 API calls"

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2013, Berend de Boer"
	license: "MIT License (see LICENSE)"


deferred class

	AWS_TOOL


inherit

	EPX_CURRENT_PROCESS

	SUS_SYSTEM


feature {NONE} -- Initialize

	make
			-- Initialize and print exception if exception occurs.
		do
			set_environment_variables
			parse_arguments
			make_no_rescue
		rescue
			if exceptions.is_developer_exception then
				stderr.put_line (exceptions.developer_exception_name)
			else
				stderr.put_string (exceptions.exception_trace)
				stderr.put_string (once "Exception code: ")
				stderr.put_line (exceptions.exception.out)
				stderr.put_line (exceptions.meaning (exceptions.exception))
			end
			exit_with_failure
		end


	make_no_rescue
		deferred
		end


feature -- Access

	default_region: STRING = "us-east-1"


feature -- Argument parsing

	parser: AP_PARSER

	description: STRING
			-- Command-line utility description
		deferred
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end

	region: AP_STRING_OPTION
			-- AWS region to operate in

	verbose: AP_FLAG
			-- Should command-line utility be verbose

	access_key: STRING

	secret_access_key: STRING

	parse_arguments
			-- Create parser, and parse given arguments.
		do
			create parser.make
			parser.set_application_description (description)
			define_arguments
			parser.parse_arguments
			validate_arguments
		end

	define_arguments
			-- Define other recognised arguments. Override to add or
			-- change arguments.
		require
			not_void: parser /= Void
		do
			create verbose.make ('v', "verbose")
			verbose.set_description ("Verbose output like progress.")
			parser.options.force_last (verbose)
			create region.make_with_long_form ("region")
			region.set_description ("Region.")
			region.set_parameter_description ("region")
			parser.options.force_last (region)
			region.set_default_parameter (default_region)
		end

	validate_arguments
			-- Parse arguments.
		require
			not_void: parser /= Void
		do
			if access_key.is_empty then
				stderr.put_line ("Environment variable AWS_ACCESS_KEY not set. It should contain your Amazon access key.")
				parser.help_option.display_usage (parser)
			end
			if secret_access_key.is_empty then
				stderr.put_line ("Environment variable AWS_SECRET_KEY not set. It should contain your Amazon secret access key.")
				parser.help_option.display_usage (parser)
			end
		end


feature -- Environment variables

	aws_access_key: STRING = "AWS_ACCESS_KEY_ID"

	aws_secret_key: STRING = "AWS_SECRET_ACCESS_KEY"

	set_environment_variables
		local
			key,
			secret_key: EPX_ENV_VAR
		do
			create key.make (aws_access_key)
			access_key := key.value
			create secret_key.make (aws_secret_key)
			secret_access_key := secret_key.value
		end

end
