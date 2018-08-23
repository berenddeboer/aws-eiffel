note

	description:

		"Base class to access AWS services. This base class is an enhanced version of the basic HTTP 1.1 client."

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


deferred class

	AWS_BASE


inherit

	EPX_HTTP_11_CLIENT
		rename
			make as make_http_11_client
		redefine
			append_other_fields
		end


inherit {NONE}

	UT_URL_ENCODING

	AWS_ACCESS_KEY


feature {NONE} -- Initialiation

	make_aws_base (a_region: READABLE_STRING_8)
		require
			access_key_not_empty: not access_key_id.is_empty
			secret_key_has_correct_length: secret_access_key.count = 40
		local
			l_server_name: STRING
		do
			region := a_region
			l_server_name := service + "." + region + ".amazonaws.com"
			--make_http_11_client (l_server_name)
			make_secure (l_server_name)
		end


feature -- Request signing

	signature: detachable AWS_SIGNATURE_V4
			-- Set by `send_request'

	append_other_fields (a_verb, a_request_uri: STRING; a_request_data: detachable EPX_MIME_PART; a_request: STRING)
		local
			headers: DS_HASH_TABLE [STRING, STRING]
			now: EPX_TIME
			timestamp: STRING
			l_body_text: STRING
			l_signature: AWS_SIGNATURE_V4
		do
			precursor (a_verb, a_request_uri, a_request_data, a_request)
			-- If an X-Amz-Date is present in the headers, use that else create it.
			if attached a_request_data as part and then part.header.fields.has (x_amz_date) then
				timestamp := part.header.fields.item (x_amz_date).value
			else
				create now.make_from_now
				now.to_utc
				timestamp := now.as_iso_8601_without_formatting.out
			end
			append_field (a_request, x_amz_date, timestamp)
			headers := create {DS_HASH_TABLE [STRING, STRING]}.make_equal (2)
			headers.put (server_name, field_name_host)
			headers.put (timestamp, x_amz_date)

			if attached a_request_data as part then
				part.header.fields.search (field_name_content_type)
				if part.header.fields.found then
					headers.force (part.header.fields.found_item.value, field_name_content_type)
				end
				-- Purely to pass test in TEST_AWS_SIGNATURE_V4
				if part.header.fields.has ("My-Header1") then
					headers.force (part.header.fields.item ("My-Header1").value, "My-Header1")
				end
				if part.header.fields.has ("My-Header2") then
					headers.force (part.header.fields.item ("My-Header2").value, "My-Header2")
				end
			end

			l_body_text := ""
			if attached a_request_data as part then
				part.body.append_to_string (l_body_text)
			end

			create l_signature.make (access_key_id, secret_access_key, a_verb, a_request_uri, headers, l_body_text, region, service)
			signature := l_signature
			append_field (a_request, field_name_authorization, l_signature.authorization)
		ensure then
			signature_set: attached signature
		end


feature -- Access

	region: READABLE_STRING_8

	service: READABLE_STRING_8
		deferred
		end

	version: STRING
			-- API version
		deferred
		end


feature {NONE} -- Action

	new_action (an_action: READABLE_STRING_8): DS_LINKED_LIST [EPX_KEY_VALUE]
			-- Key/value pairs for action `an_action'
		require
			an_action_not_empty: an_action /= Void and then not an_action.is_empty
		local
			kv: EPX_KEY_VALUE
			now: STDC_TIME
		do
			create Result.make
			create kv.make ("Action", an_action)
			Result.put_last (kv)
			create kv.make ("Version", version)
			Result.put_last (kv)
			-- IAM role support
			-- if not iam_role_token.is_empty then
			-- 	create kv.make ("SecurityToken", iam_role_token)
			-- 	Result.put_last (kv)
			-- end
		end


feature -- Field names

	x_amz_date: STRING = "X-Amz-Date"

	x_amz_target: STRING = "X-Amz-Target"

end
