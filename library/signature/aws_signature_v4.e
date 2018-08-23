note

	description:

		"Create AWS v4 signatures"

	not_working: "UTF-8 characters in path, and duplicated headers or query items."

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2018, Berend de Boer"
	canonical_reference: "https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html"
	license: "MIT License (see LICENSE)"


class

	AWS_SIGNATURE_V4


inherit {NONE}

	EPX_MIME_FIELD_NAMES


create

	make


feature {NONE} -- Implementation

	make (an_access_key, a_secret, an_http_request_method, a_uri: READABLE_STRING_8; a_signed_headers: DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]; a_payload: READABLE_STRING_8; a_region, a_service: READABLE_STRING_8)
			-- `a_uri' may contain a query string.
		require
			verb_not_empty: not an_http_request_method.is_empty
			a_uri_not_empty: not a_uri.is_empty
			a_uri_is_an_absolute_path: a_uri.item (1) = '/'
			host_required: a_signed_headers.has (field_name_host)
			x_amz_date_required: a_signed_headers.has (x_amz_date)
		local
			l_sha256: SHA256
			l_timestamp: STRING
			l_date: STRING
			l_lowercase_headers: like as_lowercase_headers
		do
			l_lowercase_headers := as_lowercase_headers (a_signed_headers)
			canonical_request := new_canonical_request (an_http_request_method, a_uri, l_lowercase_headers, a_payload)
			create l_sha256.make
			l_sha256.update_from_string (canonical_request)
			canonical_request_hash := l_sha256.digest_as_string.as_lower
			l_timestamp := a_signed_headers.item (x_amz_date)
			l_date := l_timestamp.substring (1, 8)
			credential := 	l_date + "/" + a_region + "/" + a_service + "/aws4_request"
			string_to_sign := new_string_to_sign (l_timestamp, credential, canonical_request_hash)
			signature := new_signature_key (a_secret, l_date, a_region, a_service, string_to_sign)
			authorization := algorithm + " Credential=" + an_access_key + "/" + credential  + ", SignedHeaders=" + flatten_headers (l_lowercase_headers) + ", Signature="  + signature
		end


feature -- Access

	canonical_request: READABLE_STRING_8

	canonical_request_hash: READABLE_STRING_8

	credential: READABLE_STRING_8

	string_to_sign: READABLE_STRING_8

	signature: READABLE_STRING_8

	authorization: READABLE_STRING_8

	algorithm: STRING = "AWS4-HMAC-SHA256"


feature {NONE} -- Implementation

	new_canonical_request (an_http_request_method, a_uri: READABLE_STRING_8; a_headers: DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]; a_payload: READABLE_STRING_8): STRING_8
		require
			verb_not_empty: not an_http_request_method.is_empty
			a_uri_not_empty: not a_uri.is_empty
			a_uri_is_an_absolute_path: a_uri.item (1) = '/'
			host_required: a_headers.has ("host")
			all_headers_are_lowercase: true
			headers_are_sorted: true
		local
			l_uri: UT_URI
			l_query_items: like as_sorted
			v: STRING
			sha256: SHA256
			u: UT_URI_STRING
		do
			Result := ""

			-- 1. HTTP request method
			Result.append_string (an_http_request_method)
			Result.append_character ('%N')

			-- 2. Canonical URI
			-- NOTE: does not handle S3 bucket object name with '/', see docs
			create l_uri.make (a_uri)
			-- TODO: handle utf-8 characters in path
			--create u.make_decoded (l_uri.path)
			--Result.append_string (u.encoded)
			Result.append_string (l_uri.path)
			Result.append_character ('%N')

			-- 3. Canonical query string
			if l_uri.has_query and then attached l_uri.query_items as query_items then
				l_query_items := as_sorted (query_items)
				from
					l_query_items.start
				until
					l_query_items.after
				loop
					Result.append_string (l_query_items.key_for_iteration)
					Result.append_character ('=')
					Result.append_string (l_query_items.item_for_iteration)
					l_query_items.forth
					if not l_query_items.after then
						Result.append_character ('&')
					end
				end
			end
			Result.append_character ('%N')

			-- 4. Canonical headers
			across
				a_headers as c
			loop
				Result.append_string (c.key)
				Result.append_character (':')
				v := trim_all (c.item)
				Result.append_string (v)
				Result.append_character ('%N')
			end

			-- 5. Signed headers
			Result.append_character ('%N')
			from
				a_headers.start
			until
				a_headers.after
			loop
				Result.append_string (a_headers.key_for_iteration)
				a_headers.forth
				if not a_headers.after then
					Result.append_character (';')
				end
			end
			Result.append_character ('%N')

			-- 6. Hashed payload
			if a_payload.is_empty then
				Result.append_string (empty_hashed_payload)
			else
				create sha256.make
				sha256.update_from_string (a_payload)
				Result.append_string (sha256.digest_as_string.as_lower)
			end
		end

	new_string_to_sign (an_x_amz_date, a_credential, a_canonical_request_hash: READABLE_STRING_8): STRING
		do
			Result := algorithm.out
			Result.append_character ('%N')
			Result.append_string (an_x_amz_date)
			Result.append_character ('%N')
			Result.append_string (a_credential)
			Result.append_character ('%N')
			Result.append_string (a_canonical_request_hash)
		end

	new_signature_key (a_secret, a_date, a_region, a_service, a_string_to_sign: READABLE_STRING_8): STRING
		require
			secret_not_empty: not a_secret.is_empty
			date_has_correct_length: a_date.count = 8
			region_not_empty: not a_region.is_empty
			service_not_empty: not a_service.is_empty
			string_to_sign_not_empty: not a_string_to_sign.is_empty
		local
			k_date,
			k_region,
			k_service,
			k_signing: SPECIAL [NATURAL_8]
			hmac: HMAC_SHA256
		do
			-- 1. Dervive signing key
			create hmac.make_ascii_key ("AWS4" + a_secret)
			hmac.update_from_string (a_date)
			k_date := hmac.digest
			create hmac.make (k_date)
			hmac.update_from_string (a_region)
			k_region := hmac.digest
			create hmac.make (k_region)
			hmac.update_from_string (a_service)
			k_service := hmac.digest
			create hmac.make (k_service)
			hmac.update_from_string ("aws4_request")
			k_signing := hmac.digest

			-- 2. Calculate signature
			create hmac.make (k_signing)
			hmac.update_from_string (a_string_to_sign)
			Result := hmac.lowercase_hexadecimal_string_digest
		ensure
			hash_length_ok: Result.count = 64
		end

	as_lowercase_headers (a_headers: DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]): DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]
			-- As `a_signed_headers' but hash keys are sorted in alphabetical order and in lowercase
		local
			lc_headers: like a_headers
			lc_key: STRING
			comparator: KL_COMPARABLE_COMPARATOR [STRING]
			lc_keys: DS_ARRAYED_LIST [STRING]
			sorter: DS_QUICK_SORTER [STRING]
		do
			create lc_headers.make (a_headers.count)
			create lc_keys.make (a_headers.count)
			across
				a_headers as c
			loop
				lc_key := c.key.as_lower
				lc_headers.put (c.item, lc_key)
				lc_keys.put_last (lc_key)
			end
			create comparator.make
			create sorter.make (comparator)
			lc_keys.sort (sorter)
			create Result.make (a_headers.count)
			across
				lc_keys as c
			loop
				Result.put_last (lc_headers.item (c.item), c.item)
			end
		end

	as_sorted (an_items: attached DS_HASH_TABLE [STRING, STRING]): DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]
			-- As `a_signed_headers' but hash keys are sorted in alphabetical order and in lowercase
		local
			comparator: KL_COMPARABLE_COMPARATOR [STRING]
			l_keys: DS_ARRAYED_LIST [STRING]
			sorter: DS_QUICK_SORTER [STRING]
		do
			create l_keys.make (an_items.count)
			across
				an_items as c
			loop
				l_keys.put_last (c.key)
			end
			create comparator.make
			create sorter.make (comparator)
			l_keys.sort (sorter)
			create Result.make (an_items.count)
			across
				l_keys as c
			loop
				Result.put_last (an_items.item (c.item), c.item)
			end
		end

feature {NONE} -- Implementation

	empty_hashed_payload: STRING = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

	flatten_headers (ar: DS_HASH_TABLE [READABLE_STRING_8, READABLE_STRING_8]): STRING
		do
			Result := ""
			from
				ar.start
			until
				ar.after
			loop
				Result.append_string (ar.key_for_iteration.as_lower)
				ar.forth
				if not ar.after then
					Result.append_character (';')
				end
			end
		end

	trim_all (s: READABLE_STRING_8): STRING_8
		local
			i: INTEGER
			state: INTEGER
			c: CHARACTER
		do
			Result := ""
			from
				i := 1
				state := 1
			until
				i > s.count
			loop
				c := s.item (i)
				inspect state
				when 1, 3 then
					if c /= ' ' then
						Result.append_character (c)
						state := 2
					end
				when 2 then
					Result.append_character (c)
					if c = ' ' then
						state := 3
					end
				end
				i := i + 1
			variant
				s.count - i + 1
			end
			if state = 3 then
				Result.remove_tail (1)
			end
		end


feature -- Field names

	x_amz_date: STRING = "X-Amz-Date"


end
