note

	description:

		"Tries to make snapshots of multiple disks as close to each other as possible."

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2013, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	MULTI_DISK_SNAPSHOT


inherit

	EC2_TOOL
		redefine
			define_arguments,
			validate_arguments
		end


create

	make


feature -- Help

	make_no_rescue
		local
			ec2: AWS_EC2
			volume_id: STRING
			kv: EPX_KEY_VALUE
			data: DS_LINKED_LIST [EPX_KEY_VALUE]
			form: EPX_MIME_FORM
			forms: DS_LINKED_LIST [like ec2_form]
			failure: BOOLEAN
		do
			create forms.make

			-- Prepare snapshot requests
			from
				parser.parameters.start
			until
				parser.parameters.after
			loop
				--volume_id := "vol-3d3cba60"
				volume_id := parser.parameters.item_for_iteration
				create ec2.make (access_key, secret_access_key, region.parameter)
				data := ec2.new_action ("CreateSnapshot")
				create kv.make ("VolumeId", volume_id.out)
				data.put_last (kv)
				if volume_description.was_found then
					create kv.make ("Description", volume_description.parameter)
					data.put_last (kv)
				end
				data.put_last (ec2.new_signature ("POST", "/", data))
				create form.make_form_urlencoded (data.to_array)
				forms.put_last ([ec2, form])
				parser.parameters.forth
			end

			-- Open a connection for every snapshot
			from
				forms.start
			until
				forms.after
			loop
				forms.item_for_iteration.ec2.open
				forms.forth
			end

			-- Send snapshot request
			from
				forms.start
			until
				forms.after
			loop
				form := forms.item_for_iteration.form
				ec2 := forms.item_for_iteration.ec2
				ec2.post ("/", form)
				forms.forth
			end

			-- Send snapshot request
			from
				forms.start
			until
				forms.after
			loop
				form := forms.item_for_iteration.form
				ec2 := forms.item_for_iteration.ec2
				ec2.read_response_with_redirect
				if not ec2.is_response_ok then
					print ("Response: " + ec2.response_code.out + " " + ec2.response_phrase + "%N")
					print (ec2.body.as_string)
					failure := true
				end
				forms.forth
			end
			if failure then
				exit_with_failure
			end
		end


feature -- Access

	ec2_form: TUPLE [
		ec2: AWS_EC2
		form: EPX_MIME_FORM
		]
			-- Type anchor


feature -- Arguments parsing

	description: STRING = "Make snapshot of multiple disks as close in time as possible"

	volume_description: AP_STRING_OPTION

	define_arguments
		do
			precursor

			create volume_description.make ('d', "description")
			volume_description.set_description ("Snapshot description.")
			volume_description.set_parameter_description ("description")
			parser.options.force_last (volume_description)

			parser.set_parameters_description ("volume-id [volume-id] ...")
		end

	validate_arguments
		do
			precursor
			if parser.parameters.is_empty then
				stderr.put_line ("At least one volume should be given as argument.")
				parser.help_option.display_usage (parser)
			end
		end


end
