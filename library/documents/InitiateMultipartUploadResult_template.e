note

	description: "Generated class"

class

	INITIATEMULTIPARTUPLOADRESULT_TEMPLATE

inherit

	GEDXML_TEMPLATE
		redefine
			make
		end

create

	make

feature {NONE} -- Initialisation

	make
		do
			create InitiateMultipartUploadResult
			precursor
		end

feature -- Elements

	InitiateMultipartUploadResult: TUPLE [
		Bucket: STRING
		Key: STRING
		UploadId: STRING
		]

feature -- Template reuse

	wipe_out
		do
			create InitiateMultipartUploadResult
		end

feature -- Element matching

	root_start_matcher: DS_HASH_TABLE [PROCEDURE [TUPLE], STRING]
		once
			create Result.make (1)
			Result.put (agent
				do
					create InitiateMultipartUploadResult
					save_matchers
					start_matchers := InitiateMultipartUploadResult_start_matchers
					end_matchers := InitiateMultipartUploadResult_end_matchers
				end, once "InitiateMultipartUploadResult")
		end

	InitiateMultipartUploadResult_start_matchers: DS_HASH_TABLE [PROCEDURE [TUPLE], STRING]
		once
			create Result.make (0)
		ensure
			not_void: Result /= Void
		end

	InitiateMultipartUploadResult_end_matchers: DS_HASH_TABLE [PROCEDURE [TUPLE [STRING]], STRING]
		once
			create Result.make (4)
			Result.put (agent (s: STRING)
				do
					InitiateMultipartUploadResult.Bucket := s.twin
				end, once "Bucket")
			Result.put (agent (s: STRING)
				do
					InitiateMultipartUploadResult.Key := s.twin
				end, once "Key")
			Result.put (agent (s: STRING)
				do
					InitiateMultipartUploadResult.UploadId := s.twin
				end, once "UploadId")
			Result.put (agent (s: STRING)
				do
					restore_matchers
				end, once "InitiateMultipartUploadResult")
		ensure
			not_void: Result /= Void
		end

end
