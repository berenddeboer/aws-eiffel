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
		redefine
			append_other_fields
		end


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

	max_retries: INTEGER = 5
			-- How often should requests be retried

	service: STRING = "s3"

	bucket: READABLE_STRING_8
			-- Bucket

	version: STRING
			-- Not used.


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
			empty: EPX_MIME_PART
		do
			create parts.make
			create empty.make_empty
			post ("/" + an_object_name + "?uploads", empty)
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



feature -- Request signing

	append_other_fields (a_verb, a_request_uri: STRING; a_request_data: detachable EPX_MIME_PART; a_request: STRING)
		do
			append_field (a_request, x_amz_content_sha256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
			precursor (a_verb, a_request_uri, a_request_data, a_request)
		end


feature -- Field names

	x_amz_content_sha256: STRING = "X-Amz-Content-SHA256"


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
		ensure
			not_void: Result /= Void
		end


end
