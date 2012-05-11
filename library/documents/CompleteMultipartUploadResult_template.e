note

description: "Generated class"

class

	COMPLETEMULTIPARTUPLOADRESULT_TEMPLATE

inherit

	GEDXML_TEMPLATE

create

	make

feature -- Elements

	CompleteMultipartUploadResult: TUPLE [
		Location: STRING
		Bucket: STRING
		Key: STRING
		ETag: STRING
		]

feature -- Template reuse

	wipe_out
		do
			CompleteMultipartUploadResult := Void
		end

feature -- Element matching

	root_start_matcher: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE []], STRING]
		once
			create Result.make (1)
			Result.put (agent
				do
					create CompleteMultipartUploadResult
					save_matchers
					start_matchers := CompleteMultipartUploadResult_start_matchers
					end_matchers := CompleteMultipartUploadResult_end_matchers
				end, once "CompleteMultipartUploadResult")
		end

	CompleteMultipartUploadResult_start_matchers: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE []], STRING]
		once
			create Result.make (0)
		ensure
			not_void: Result /= Void
		end

	CompleteMultipartUploadResult_end_matchers: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE [STRING]], STRING]
		once
			create Result.make (5)
			Result.put (agent (s: STRING)
				do
					CompleteMultipartUploadResult.Location := s.twin
				end, once "Location")
			Result.put (agent (s: STRING)
				do
					CompleteMultipartUploadResult.Bucket := s.twin
				end, once "Bucket")
			Result.put (agent (s: STRING)
				do
					CompleteMultipartUploadResult.Key := s.twin
				end, once "Key")
			Result.put (agent (s: STRING)
				do
					CompleteMultipartUploadResult.ETag := s.twin
				end, once "ETag")
			Result.put (agent (s: STRING)
				do
					restore_matchers
				end, once "CompleteMultipartUploadResult")
		ensure
			not_void: Result /= Void
		end

end
