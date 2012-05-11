note

description: "Generated class"

class

	ERROR_TEMPLATE

inherit

	GEDXML_TEMPLATE

create

	make

feature -- Elements

	Error: TUPLE [
		Code: STRING
		Message: STRING
		RequestId: STRING
		HostId: STRING
		]

feature -- Template reuse

	wipe_out
		do
			Error := Void
		end

feature -- Element matching

	root_start_matcher: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE []], STRING]
		once
			create Result.make (1)
			Result.put (agent
				do
					create Error
					save_matchers
					start_matchers := Error_start_matchers
					end_matchers := Error_end_matchers
				end, once "Error")
		end

	Error_start_matchers: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE []], STRING]
		once
			create Result.make (0)
		ensure
			not_void: Result /= Void
		end

	Error_end_matchers: DS_HASH_TABLE [PROCEDURE [ANY, TUPLE [STRING]], STRING]
		once
			create Result.make (5)
			Result.put (agent (s: STRING)
				do
					Error.Code := s.twin
				end, once "Code")
			Result.put (agent (s: STRING)
				do
					Error.Message := s.twin
				end, once "Message")
			Result.put (agent (s: STRING)
				do
					Error.RequestId := s.twin
				end, once "RequestId")
			Result.put (agent (s: STRING)
				do
					Error.HostId := s.twin
				end, once "HostId")
			Result.put (agent (s: STRING)
				do
					restore_matchers
				end, once "Error")
		ensure
			not_void: Result /= Void
		end

end
