
FUNCTION_BLOCK TCPChatFB (*FB template for Enable FB*)
	VAR_INPUT
		Enable : BOOL; (*Enable the function block*)
		Update : BOOL; (*Update parameters*)
		Parameters : TCPChatParametersType; (*Parameter required for computing*)
		Reset : BOOL;
		MessageToSend : STRING[tcpchatMESSAGE_LEN]; (*Input variable*)
	END_VAR
	VAR_OUTPUT
		Active : BOOL; (*Function block is active*)
		Error : BOOL; (*Indicates an error*)
		StatusID : DINT; (*Status information*)
		MessageReceived : STRING[tcpchatMESSAGE_LEN]; (*Output variable*)
	END_VAR
	VAR
		Internal : TCPChatFBInternalType; (*Data for internal use*)
	END_VAR
END_FUNCTION_BLOCK
