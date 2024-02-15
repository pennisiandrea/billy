
PROGRAM _INIT
	TcpChat1.Parameters.ServerIPAddress := '127.0.0.1';
	TcpChat1.Parameters.ServerPort := 12000;
	TcpChat1.Parameters.ServerRole := FALSE;
	
	TcpChat2.Parameters.ServerIPAddress := '127.0.0.1';
	TcpChat2.Parameters.ServerPort := 12000;
	TcpChat2.Parameters.ServerRole := TRUE;
END_PROGRAM

PROGRAM _CYCLIC
	TcpChat1();
	TcpChat2();
END_PROGRAM

PROGRAM _EXIT
	 
END_PROGRAM

