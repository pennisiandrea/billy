
TYPE
	TCPChatFBInternalType : 	STRUCT  (*Template of a structure of internal parameters for an enable function block *)
		Enabled : BOOL; (*Variable to detect rising edge on Enable input*)
		Updated : BOOL; (*Variable to detect rising edge of Update input*)
		Reseted : BOOL; (*Variable to detect rising edge of Reset input*)
		ParametersValid : BOOL; (*All parameters valid flag*)
		Parameters : TCPChatParametersType; (*Internal parameter for computing*)
		TcpOpenLocalInterface : TcpOpen; (*AsTCP.TcpOpen FUB*)
		TcpClientConnection : TcpClient; (*AsTCP.TcpClient FUB*)
		TcpReceiveMessage : TcpRecv; (*AsTCP.TcpRecv FUB*)
		TcpSendMessage : TcpSend; (*AsTCP.TcpSend FUB*)
		TcpCloseConnection : TcpClose; (*AsTCP.TcpClose FUB*)
		TcpServerInstance : TcpServer; (*AsTCP.TcpClose FUB*)
		MachineStateStep : UINT;
		SendingMessage : STRING[tcpchatMESSAGE_LEN];
		LastMessageSent : STRING[tcpchatMESSAGE_LEN];
		RetryOpenLocalCnt : USINT;
		RetryClientConnectionCnt : USINT;
		SocketIDs : ARRAY[0..tcpchatMAX_CONNECTIONS_NUM]OF UDINT;
	END_STRUCT;
	TCPChatParametersType : 	STRUCT 
		ServerIPAddress : STRING[15];
		ServerPort : UINT;
		ServerRole : BOOL;
	END_STRUCT;
END_TYPE
