note

	description:

		"S3 REST interface"

	library: "S3 library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2008-2011, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	S3_CLIENT


inherit

	AWS_BASE


inherit {NONE}

	UC_SHARED_STRING_EQUALITY_TESTER
		export
			{NONE} all
		end


create

	make



feature {NONE} -- Initialization

	make (a_region, a_bucket: READABLE_STRING_8)
		require
			access_key_not_empty: not access_key_id.is_empty
			secret_key_has_correct_length: secret_access_key.count = 40
			a_region_not_empty: not a_region.is_empty
		local
			l_server_name: STRING
		do
			bucket := a_bucket
			region := a_region
			l_server_name := bucket + ".s3." + region + ".amazonaws.com"
			make_secure (l_server_name)
		end


feature -- Access

	max_retries: NATURAL_32 = 0
			-- How often should requests be retried

	service: STRING = "s3"

	bucket: READABLE_STRING_8
			-- Bucket

	version: STRING = ""
			-- Not used


feature -- Amazon primitives

	get_object (a_key: STRING)
			-- Send GET request for an object to S3.
		require
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
		local
			l_data: EPX_MIME_PART
		do
			--get (once "/" + a_key)
			create l_data.make_empty
			add_x_amz_content_sha256_field (l_data)
			send_request (http_method_GET, once "/" + a_key, l_data)
		end

	put_object (a_bucket, a_key: STRING; a_size: INTEGER)
			-- Send PUT request for an object to S3.
			-- Assumes data itself is written straight to `http'
		require
			a_bucket_not_empty: a_bucket /= Void and then not a_bucket.is_empty
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
			size_not_negative: a_size >= 0
		local
			l_data: EPX_MIME_PART
		do
			create l_data.make_empty
			l_data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			l_data.header.set_content_length (a_size)
			-- TODO: X-Amz-Content-SHA256 field required.
			send_request (http_method_POST, once "/" + a_bucket + once "/" + a_key, l_data)
		end


feature -- Multipart upload

	parts: detachable DS_LINKED_LIST [STRING]
			-- Keep track of uploaded parts

	multipart_upload_id (an_object_name: STRING): STRING
			-- A new multipart upload id
		require
			an_object_name_not_empty: an_object_name /= Void and then not an_object_name.is_empty
		local
			l_d: INITIATEMULTIPARTUPLOADRESULT_DOCUMENT
			l_data: EPX_MIME_PART
		do
			create parts.make
			create l_data.make_empty
			l_data.header.set_content_type ("binary", "octet-stream", Void)
			add_x_amz_content_sha256_field (l_data)
			post ("/" + an_object_name + "?uploads", l_data)
			read_response
			if is_response_ok and then attached body as l_body then
				create l_d.make_from_string (l_body.as_string)
				Result := l_d.InitiateMultipartUploadResult.UploadId
			else
				Result := ""
			end
		ensure
			has_upload_id: is_response_ok implies not Result.is_empty
			parts_attached: attached parts
		end

	begin_part_upload (an_upload_id, an_object_name: READABLE_STRING_GENERAL; a_size: INTEGER; a_payload_hash: READABLE_STRING_8)
			-- Send upload part request. Afterwards client can use
			-- `http'.`put_buffer' to write bytes.
		require
			an_upload_id_not_empty: not an_upload_id.is_empty
			an_object_name_not_empty: not an_object_name.is_empty
			size_not_negative: a_size >= 0
			multipart_upload_started: attached parts
			not_too_many_parts: attached parts as l_parts and then l_parts.count <= 10000
		local
			l_data: EPX_MIME_PART
		do
			create l_data.make_empty
			l_data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			-- As we use X-Amz-Content-SHA256 we don't need Content-MD5.
			--l_data.header.add_new_field (x_amz_content_sha256, "UNSIGNED-PAYLOAD")
			l_data.header.add_new_field (x_amz_content_sha256, a_payload_hash)
			l_data.header.set_content_length (a_size)
			if attached parts as l_parts then
				send_request (http_method_PUT, once "/" + an_object_name + once "?partNumber=" + (l_parts.count + 1).out + "&uploadId=" + an_upload_id, l_data)
			end
			if attached tcp_socket as l_tcp_socket then
				l_tcp_socket.set_blocking_io (False)
			end
		end

	end_part_upload
			-- Read response after writing payload has been finished.
		require
			parts_set: attached parts
		local
			l_etag: STRING
		do
			if attached tcp_socket as l_tcp_socket then
				l_tcp_socket.set_blocking_io (True)
			end
			read_response
			if is_response_ok then
				-- Let's hope Amazon never changes the case of their
				-- header, that would break us.
				l_etag := fields.item (once "Etag").value
				if attached parts as l_parts then
					l_parts.put_last (l_etag)
				end
				close
			end
		ensure
			closed: is_response_ok implies not is_open
		end

	complete_multipart_upload (an_upload_id, an_object_name: STRING)
			-- Finish an initiated multi-part upload.
		require
			an_upload_id_not_empty: not an_upload_id.is_empty
			an_object_name_not_empty: not an_object_name.is_empty
			multipart_upload_started: attached parts
		local
			l_xml: EPX_XML_WRITER
			l_data: EPX_MIME_PART
			i: INTEGER
		do
			create l_xml.make
			l_xml.add_header_utf_8_encoding
			l_xml.start_tag (once "CompleteMultipartUpload")
			if attached parts as l_parts then
				from
					l_parts.start
					i := 1
				until
					l_parts.after
				loop
					l_xml.start_tag ("Part")
					l_xml.add_tag ("PartNumber", i.out)
					l_xml.add_tag ("ETag", l_parts.item_for_iteration)
					l_xml.stop_tag
					l_parts.forth
					i := i + 1
				end
			end
			l_xml.stop_tag
			create l_data.make_empty
			l_data.header.set_content_type (mime_type_binary, mime_subtype_octet_stream, Void)
			l_data.create_singlepart_body
			if attached l_data.text_body as l_body then
				l_body.append_string (l_xml.as_string)
			end
			add_x_amz_content_sha256_field (l_data)
			post ("/" + an_object_name + "?uploadId=" + an_upload_id, l_data)
			read_response
			-- It appears we should actually wait here to read the
			-- response as even a 200 OK might still become a failure.
			parts := Void
		end


feature -- Amazon higher level functions

	retrieve_object_header_with_retry (a_key: STRING)
			-- As S3 fails a lot, this function retries up to `max_retries'
			-- times to send a request and read the response header.
			-- Retrieving the body may still fail of course.
			-- It is advisable that `set_continue_on_error' is called
			-- before, to be resilient against network errors as well.
		require
			a_key_not_empty: a_key /= Void and then not a_key.is_empty
		local
			l_retries: NATURAL_32
			l_done: BOOLEAN
		do
			from
			until
				l_done or else
				l_retries > max_retries
			loop
				get_object (a_key)
				if attached http as l_http then
					if l_http.errno.is_ok then
						read_response_header
						if l_http.errno.is_ok then
							l_done := response_code < 500 and then response_code > 599
						end
					end
				end
				l_retries := l_retries + 1
			end
		end


feature {NONE} -- Payload signing

	empty_string_hash: STRING = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

	add_x_amz_content_sha256_field (a_data: EPX_MIME_PART)
			-- Add the X-Amz-Content-SHA256 field if one does not yet exist.
		local
			l_sha256: SHA256
			l_hash: STRING
		do
			if not a_data.header.has (x_amz_content_sha256) then
				if attached a_data.text_body as l_payload then
					create l_sha256.make
					l_sha256.update_from_string (l_payload.as_string)
					l_hash := l_sha256.digest_as_string.as_lower
				else
					l_hash := empty_string_hash
				end
				a_data.header.add_new_field (x_amz_content_sha256, l_hash)
			end
		ensure
			has_x_amz_content_sha256: a_data.header.has (x_amz_content_sha256)
		end


feature {NONE} -- Implementation

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
		end


end
