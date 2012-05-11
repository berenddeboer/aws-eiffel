note

	description:

		"S3 REST interface"

	library: "S3 library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2011, Berend de Boer"
	license: "MIT License (see LICENSE)"
	date: "$Date$"
	revision: "$Revision$"


class

	S3_CLIENT


inherit

	EPX_HTTP_11_CLIENT
		rename
			make as make_http_11_client
		redefine
			append_other_fields
		end


inherit {NONE}

	UC_SHARED_STRING_EQUALITY_TESTER


create

	make



feature {NONE} -- Initialization

	make (an_access_key_id, a_secret_access_key, a_region, a_bucket: STRING)
		require
			access_key_has_correct_length: an_access_key_id /= Void and then an_access_key_id.count = 20
			secret_key_has_correct_length: a_secret_access_key /= Void and then a_secret_access_key.count = 40
			a_bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
		do
			region := a_region
			bucket := a_bucket
			if region = Void or else region.is_empty then
				s3_host_name := bucket + ".s3.amazonaws.com"
			else
				s3_host_name := bucket + ".s3-" + region + ".amazonaws.com"
			end
			make_http_11_client (s3_host_name)
			access_key_id := an_access_key_id
			create hasher.make (a_secret_access_key, create {EPX_SHA1_CALCULATION}.make)
		end


feature -- Amazon primitives

	get_object (a_bucket, a_key: STRING)
			-- Send GET request for an object to S3.
		require
			a_bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
		do
			get (once "/" + a_bucket + once "/" + a_key)
		end

	put_object (a_bucket, a_key: STRING; a_size: INTEGER)
			-- Send PUT request for an object to S3.
			-- Assumes data itself is written straight to `http'
		require
			a_bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
			size_not_negative: a_size >= 0
		local
			data: EPX_MIME_PART
		do
			create data.make_empty
			data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			data.header.set_content_length (a_size)
			send_request (http_method_POST, once "/" + a_bucket + once "/" + a_key, data)
		end


feature -- Multipart upload

	parts: detachable DS_LINKED_LIST [STRING]
			-- Keep track of uploaded parts

	multipart_upload_id (an_object_name: STRING): STRING
			-- A new multipart upload id
		require
			an_object_name_not_empty: an_object_name /= Void and then not an_object_name.is_empty
			not_secure: not is_secure_connection
		local
			d: INITIATEMULTIPARTUPLOADRESULT_DOCUMENT
		do
			create parts.make
			post ("/" + an_object_name + "?uploads", Void)
			read_response
			if is_response_ok then
				create d.make_from_string (body.as_string)
				Result := d.InitiateMultipartUploadResult.UploadId
			end
		ensure
			has_upload_id: is_response_ok implies Result /= Void and then not Result.is_empty
		end

	begin_part_upload (an_upload_id, an_object_name: STRING; a_size: INTEGER)
			-- Send upload part request. Afterwards client can use
			-- `http'.`put_buffer' to write bytes.
		require
			an_upload_id_not_empty: an_upload_id /= Void and then not an_upload_id.is_empty
			an_object_name_not_empty: an_object_name /= Void and then not an_object_name.is_empty
			size_not_negative: a_size >= 0
			multipart_upload_started: parts /= Void
			not_too_many_parts: parts.count <= 10000
		local
			data: EPX_MIME_PART
		do
			create data.make_empty
			data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			data.header.set_content_length (a_size)
			send_request (http_method_PUT, once "/" + an_object_name + once "?partNumber=" + (parts.count + 1).out + "&uploadId=" + an_upload_id, data)
			tcp_socket.set_blocking_io (False)
		end

	end_part_upload
		local
			etag: STRING
		do
			tcp_socket.set_blocking_io (True)
			--tcp_socket.shutdown_write
			read_response
			if is_response_ok then
				-- Let's hope Amazon never changes the case of their
				-- header, that would break us.
				etag := fields.item (once "Etag").value
				parts.put_last (etag)
				close
			end
		ensure
			closed: is_response_ok implies not is_open
		end

	complete_multipart_upload (an_upload_id, an_object_name: STRING)
			-- Finish an initiated multi-part upload.
		require
			an_upload_id_not_empty: an_upload_id /= Void and then not an_upload_id.is_empty
			an_object_name_not_empty: an_object_name /= Void and then not an_object_name.is_empty
			multipart_upload_started: parts /= Void
		local
			xml: EPX_XML_WRITER
			data: EPX_MIME_PART
			i: INTEGER
		do
			create xml.make
			xml.add_header_utf_8_encoding
			xml.start_tag (once "CompleteMultipartUpload")
			from
				parts.start
				i := 1
			until
				parts.after
			loop
				xml.start_tag ("Part")
				xml.add_tag ("PartNumber", i.out)
				xml.add_tag ("ETag", parts.item_for_iteration)
				xml.stop_tag
				parts.forth
				i := i + 1
			end
			xml.stop_tag
			create data.make_empty
			data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			data.create_singlepart_body
			data.text_body.append_string (xml.as_string)
			post ("/" + an_object_name + "?uploadId=" + an_upload_id, data)
			read_response
			-- It appears we should actually wait here to read the
			-- response as even a 200 OK might still become a failure.
			parts := Void
		end


feature -- Amazon higher level functions

	retrieve_object_header_with_retry (a_bucket, a_key: STRING)
			-- As S3 fails a lot, this function retries up to `max_retries'
			-- times to send a request and read the response header.
			-- Retrieving the body may still fail of course.
			-- It is advisable that `set_continue_on_error' is called
			-- before to be resilient against network errors as well.
		require
			a_bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
		local
			retries: INTEGER
			done: BOOLEAN
		do
			from
			until
				done or else
				retries > max_retries
			loop
				get_object (a_bucket, a_key)
				if http.errno.is_ok then
					read_response_header
					if http.errno.is_ok then
						done := response_code /= 500 and then response_code /= 502 and then response_code /= 503 and then response_code /= 504
					end
				end
				retries := retries + 1
			end
		end


feature -- Accesss

	access_key_id: STRING
			-- Access Key ID (a 20-character, alphanumeric sequence)

	max_retries: INTEGER = 5
			-- How often should requests be retried

	s3_host_name: STRING

	region: STRING
			-- Optional region

	bucket: STRING
			-- Bucket


feature {NONE} -- Implementation

	append_other_fields (a_verb, a_path: STRING; a_request_data: EPX_MIME_PART; request: STRING)
		local
			now: STDC_TIME
			date: STRING
			content_type: STRING
			uri: UT_URI
			signature: STRING
			i: INTEGER
			parameters: ARRAY [STRING]
			name_value: STRING
			name: STRING
			p: INTEGER
			first_time: BOOLEAN
			exclude_acl: BOOLEAN
		do
			create uri.make (a_path)
			if uri.has_query and then uri.query.has_substring ("uploadId=") then
				exclude_acl := true
			end

			-- Append Amazon's special signature field
			if a_request_data /= Void and then a_request_data.header.content_type /= Void then
				content_type := a_request_data.header.content_type.value
			end
			create now.make_from_now
			now.to_utc
			date := now.rfc_date_string
			create signature.make (256)
			signature.append_string (a_verb)
			signature.append_character ('%N')
			-- No MD5
			signature.append_character ('%N')
			signature.append_string (content_type)
			signature.append_character ('%N')
			signature.append_string (date)
			if not exclude_acl then
				signature.append_string (once "%Nx-amz-acl:")
				signature.append_string (acl)
			end
			signature.append_character ('%N')
			-- Append path
			signature.append_string ("/" + bucket + uri.path)
			-- Append sub-resource(s)
			if uri.has_query then
				parameters := sh.split_on (uri.query, '&')
				first_time := true
				from
					i := parameters.lower
				until
					i > parameters.upper
				loop
					name_value := parameters [i]
					p := name_value.index_of ('=', 1)
					if p = 0 then
						name := name_value
					else
						name := name_value.substring (1, p - 1)
					end
					if sub_resources.has (name) then
						if first_time then
							signature.append_character ('?')
							first_time := false
						else
							signature.append_character ('&')
						end
						signature.append_string (name_value)
					end
					i := i + 1
				end
			end
			if hasher.is_checksum_available then
				hasher.wipe_out
			end
			hasher.put_string (signature)
			hasher.finalize
			request.append (once "Date: ")
			request.append (date)
			request.append_string (once_new_line)
			-- ACL header, not applicable for all requests
			if not exclude_acl then
				request.append (once "x-amz-acl: ")
				request.append (acl)
				request.append_string (once_new_line)
			end
			request.append (field_name_authorization)
			request.append_string (once_colon_space)
			request.append_string (once "AWS ")
			request.append_string (access_key_id)
			request.append_character (':')
			request.append_string (as_base64 (hasher.binary_checksum))
			request.append_string (once_new_line)
		end

	as_base64 (buf: STDC_BUFFER): STRING
			-- Entire buffer in base64 encoding
		require
			buf_not_void: buf /= Void
		local
			output: KL_STRING_OUTPUT_STREAM
			base64: UT_BASE64_ENCODING_OUTPUT_STREAM
		do
			create Result.make (hasher.hash_output_length * 2)
			create output.make (Result)
			create base64.make (output, False, False)
			base64.put_string (buf.substring (0, buf.capacity-1))
			base64.close
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end


feature {NONE} -- Implementation

	acl: STRING = "private"

	hasher: EPX_HMAC_CALCULATION

	sub_resources: DS_HASH_SET [STRING]
			-- Known sub resources as per http://docs.amazonwebservices.com/AmazonS3/latest/dev/RESTAuthentication.html
		do
			create Result.make (14)
			Result.set_equality_tester (string_equality_tester)
			Result.put_last ("acl")
			Result.put_last ("location")
			Result.put_last ("logging")
			Result.put_last ("notification")
			Result.put_last ("partNumber")
			Result.put_last ("policy")
			Result.put_last ("requestPayment")
			Result.put_last ("torrent")
			Result.put_last ("uploadId")
			Result.put_last ("uploads")
			Result.put_last ("versionId")
			Result.put_last ("versioning")
			Result.put_last ("versions")
			Result.put_last ("website")
		ensure
			not_void: Result /= Void
		end

invariant

	access_key_has_correct_length: access_key_id /= Void and then access_key_id.count = 20
	hasher_not_void: hasher /= Void
	s3_host_name_not_empty: s3_host_name /= Void and then not s3_host_name.is_empty

end
