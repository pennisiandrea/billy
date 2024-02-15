ACTION TCPChatFBCheckParameters:
    IF strlen(ADR(Parameters.ServerIPAddress)) = 0 THEN
		StatusID := tcpERR_PARAMETER; 
		Error := TRUE;
	ELSIF Parameters.ServerPort = 0 THEN
		StatusID := tcpERR_PARAMETER; 
		Error := TRUE;
	ELSE
		Error := FALSE;
        Internal.Parameters := Parameters;
        Internal.ParametersValid := TRUE;	
    END_IF;
END_ACTION


ACTION TCPChatFBCyclicClientCode:
	
	CASE Internal.MachineStateStep OF
        
		0: // Init
			StatusID := ERR_FUB_BUSY;
			
			TCPChatFBResetOutputs;
			
			Internal.RetryOpenLocalCnt := 0;
			Internal.RetryClientConnectionCnt := 0;
			
			memset(ADR(Internal.LastMessageSent),0,SIZEOF(Internal.LastMessageSent));
			
			Internal.MachineStateStep := 10;
			
		10: // Open Ethernet Interface 	
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpOpenLocalInterface.enable := TRUE;		
			Internal.TcpOpenLocalInterface.pIfAddr := 0; // Client listen on all interfaces
			Internal.TcpOpenLocalInterface.port := 0; // A free port is asigned automatically  
			Internal.TcpOpenLocalInterface.options := 0;	
			Internal.TcpOpenLocalInterface();  // Call the Function 
						
			IF Internal.TcpOpenLocalInterface.status = ERR_OK THEN 
				Internal.SocketIDs[0] := Internal.TcpOpenLocalInterface.ident;
				Internal.RetryOpenLocalCnt := 0;
				Internal.MachineStateStep := 20;											
			ELSIF Internal.TcpOpenLocalInterface.status = ERR_FUB_BUSY THEN  				
				// wait										
			ELSIF Internal.TcpOpenLocalInterface.status = tcpERR_ALREADY_EXIST AND Internal.RetryOpenLocalCnt = 0 THEN  
				Internal.SocketIDs[0] := Internal.TcpOpenLocalInterface.ident;
				Internal.RetryOpenLocalCnt := Internal.RetryOpenLocalCnt + 1;
				Internal.MachineStateStep := 11;
			ELSE  
				StatusID := Internal.TcpOpenLocalInterface.status;
				Internal.MachineStateStep := 99;
			END_IF
		
		11: // Close socket due to an error -> after this state it retries to establish a connection
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpCloseConnection.enable := TRUE;	
			Internal.TcpCloseConnection.ident := Internal.SocketIDs[0];  
			Internal.TcpCloseConnection.how := 0;
			Internal.TcpCloseConnection();  
	
			IF Internal.TcpCloseConnection.status <> ERR_FUB_BUSY THEN  	
				Internal.SocketIDs[0] := 0;
				Internal.MachineStateStep := 10;
			END_IF
			
		20: // Connect to the other Station 		
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpClientConnection.enable := TRUE;	
			Internal.TcpClientConnection.ident := Internal.SocketIDs[0];  
			Internal.TcpClientConnection.portserv := Internal.Parameters.ServerPort;  
			Internal.TcpClientConnection.pServer := ADR(Internal.Parameters.ServerIPAddress);  
			Internal.TcpClientConnection();  
			
			IF Internal.TcpClientConnection.status = ERR_OK THEN  
				Internal.RetryClientConnectionCnt := 0;
				Internal.MachineStateStep := 30;	
			ELSIF Internal.TcpClientConnection.status = ERR_FUB_BUSY THEN  		
				// wait										
			ELSIF Internal.TcpClientConnection.status = tcpERR_ALREADY_CONNECTED AND Internal.RetryClientConnectionCnt = 0 THEN  
				Internal.RetryClientConnectionCnt := Internal.RetryClientConnectionCnt + 1;
				Internal.MachineStateStep := 11;
			ELSIF Internal.TcpClientConnection.status = tcpERR_INVALID THEN  // wait server		
				// wait	
			ELSE  
				StatusID := Internal.TcpClientConnection.status;
				Internal.MachineStateStep := 99;
			END_IF
		            
		30: // Wait a message to be sent and listen for message from server
			StatusID := ERR_OK;
			
			IF MessageToSend <> Internal.LastMessageSent THEN // Check if a new message is waiting to be sent
				IF strlen(ADR(MessageToSend)) > 0 THEN
					Internal.SendingMessage := MessageToSend;
					Internal.MachineStateStep := 40;
				ELSE
					Internal.LastMessageSent := MessageToSend;
				END_IF
			
			ELSE
				Internal.TcpReceiveMessage.enable := TRUE;	
				Internal.TcpReceiveMessage.ident := Internal.SocketIDs[0];  
				Internal.TcpReceiveMessage.pData := ADR(MessageReceived); 
				Internal.TcpReceiveMessage.datamax := SIZEOF(MessageReceived);  
				Internal.TcpReceiveMessage.flags := 0;
				Internal.TcpReceiveMessage(); 
			
				IF Internal.TcpReceiveMessage.status = ERR_OK THEN  
					// do nothing
				ELSIF Internal.TcpReceiveMessage.status = tcpERR_NO_DATA THEN 
					// do nothing					
				ELSIF Internal.TcpReceiveMessage.status = ERR_FUB_BUSY THEN  			
					// wait					
				ELSIF Internal.TcpReceiveMessage.status = tcpERR_NOT_CONNECTED THEN  			
					Internal.MachineStateStep := 11;
				ELSE  
					StatusID := Internal.TcpReceiveMessage.status;
					Internal.MachineStateStep := 99;
				END_IF
			END_IF
					
		40: // Send Data to the Server	
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpSendMessage.enable := TRUE;					
			Internal.TcpSendMessage.ident := Internal.SocketIDs[0]; 
			Internal.TcpSendMessage.pData := ADR(Internal.SendingMessage);  
			Internal.TcpSendMessage.datalen := SIZEOF(Internal.SendingMessage);  								
			Internal.TcpSendMessage.flags := 0;
			Internal.TcpSendMessage();  
				
			IF Internal.TcpSendMessage.status = ERR_OK THEN  
				Internal.LastMessageSent := Internal.SendingMessage;
				Internal.MachineStateStep := 30;
			ELSIF Internal.TcpSendMessage.status = ERR_FUB_BUSY THEN  			
				// wait					
			ELSIF Internal.TcpSendMessage.status = tcpERR_NOT_CONNECTED THEN  			
				Internal.MachineStateStep := 11;
			ELSE  
				StatusID := Internal.TcpSendMessage.status;
				Internal.MachineStateStep := 99;
			END_IF
								
		99: // An error occured -> close connection and go to error state			
			IF Internal.SocketIDs[0] <> 0 THEN
				Internal.TcpCloseConnection.enable := TRUE;	
				Internal.TcpCloseConnection.ident := Internal.SocketIDs[0];  
				Internal.TcpCloseConnection.how := 0;
				Internal.TcpCloseConnection();   
		
				IF Internal.TcpCloseConnection.status <> ERR_FUB_BUSY THEN  	
					Internal.SocketIDs[0] := 0;
				END_IF
			ELSE
			
				IF Reset AND NOT Internal.Reseted THEN
					Internal.Reseted := TRUE;
					Internal.MachineStateStep := 0;
				END_IF
			END_IF
        
		ELSE
			Internal.MachineStateStep := 0;			
        
	END_CASE
	
	IF NOT Reset THEN
		Internal.Reseted := FALSE;
	END_IF
	
	Active := Internal.MachineStateStep = 30 OR Internal.MachineStateStep = 40;
	Error := Internal.MachineStateStep = 99;
END_ACTION

ACTION TCPChatFBCyclicServerCode:
	CASE Internal.MachineStateStep OF
        
		0: // Init
			StatusID := ERR_FUB_BUSY;
			
			TCPChatFBResetOutputs;
			
			Internal.RetryOpenLocalCnt := 0;
			Internal.RetryClientConnectionCnt := 0;
			
			memset(ADR(Internal.LastMessageSent),0,SIZEOF(Internal.LastMessageSent));
			memset(ADR(Internal.SocketIDs),0,SIZEOF(Internal.SocketIDs));
			
			Internal.MachineStateStep := 10;
			
		10: // Open Ethernet Interface 	
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpOpenLocalInterface.enable := TRUE;		
			Internal.TcpOpenLocalInterface.pIfAddr := 0; // Client listen on all interfaces
			Internal.TcpOpenLocalInterface.port := 0; // A free port is asigned automatically  
			Internal.TcpOpenLocalInterface.options := 0;	
			Internal.TcpOpenLocalInterface();  // Call the Function 
						
			IF Internal.TcpOpenLocalInterface.status = ERR_OK THEN 
				Internal.SocketIDs[0] := Internal.TcpOpenLocalInterface.ident;
				Internal.RetryOpenLocalCnt := 0;
				Internal.MachineStateStep := 20;											
			ELSIF Internal.TcpOpenLocalInterface.status = ERR_FUB_BUSY THEN  				
				// wait										
			ELSIF Internal.TcpOpenLocalInterface.status = tcpERR_ALREADY_EXIST AND Internal.RetryOpenLocalCnt = 0 THEN  
				Internal.SocketID := Internal.TcpOpenLocalInterface.ident;
				Internal.RetryOpenLocalCnt := Internal.RetryOpenLocalCnt + 1;
				Internal.MachineStateStep := 11;
			ELSE  
				StatusID := Internal.TcpOpenLocalInterface.status;
				Internal.MachineStateStep := 99;
			END_IF
		
		11: // Close socket due to an error -> after this state it retries to establish a connection
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpCloseConnection.enable := TRUE;	
			Internal.TcpCloseConnection.ident := Internal.SocketIDs[0];  
			Internal.TcpCloseConnection.how := 0;
			Internal.TcpCloseConnection();  
	
			IF Internal.TcpCloseConnection.status <> ERR_FUB_BUSY THEN  	
				Internal.SocketIDs[0] := 0;
				Internal.MachineStateStep := 10;
			END_IF
			
		20: // Connect to the other Station 		
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpServerInstance.enable := TRUE;	
			Internal.TcpServerInstance.ident := Internal.SocketIDs[0];  
			Internal.TcpServerInstance.backlog := 1;
			Internal.TcpServerInstance.portserv := Internal.Parameters.ServerPort;  
			Internal.TcpServerInstance.pServer := ADR(Internal.Parameters.ServerIPAddress);  
			Internal.TcpServerInstance();  
			
			IF Internal.TcpClientConnection.status = ERR_OK THEN  
				Internal.RetryClientConnectionCnt := 0;
				Internal.MachineStateStep := 30;	
			ELSIF Internal.TcpClientConnection.status = ERR_FUB_BUSY THEN  		
				// wait										
			ELSIF Internal.TcpClientConnection.status = tcpERR_ALREADY_CONNECTED AND Internal.RetryClientConnectionCnt = 0 THEN  
				Internal.RetryClientConnectionCnt := Internal.RetryClientConnectionCnt + 1;
				Internal.MachineStateStep := 11;
			ELSIF Internal.TcpClientConnection.status = tcpERR_INVALID THEN  // wait server		
				// wait	
			ELSE  
				StatusID := Internal.TcpClientConnection.status;
				Internal.MachineStateStep := 99;
			END_IF
		            
		30: // Wait a message to be sent and listen for message from server
			StatusID := ERR_OK;
			
			IF MessageToSend <> Internal.LastMessageSent THEN // Check if a new message is waiting to be sent
				IF strlen(ADR(MessageToSend)) > 0 THEN
					Internal.SendingMessage := MessageToSend;
					Internal.MachineStateStep := 40;
				ELSE
					Internal.LastMessageSent := MessageToSend;
				END_IF
			
			ELSE
				Internal.TcpReceiveMessage.enable := TRUE;	
				Internal.TcpReceiveMessage.ident := Internal.SocketID;  
				Internal.TcpReceiveMessage.pData := ADR(MessageReceived); 
				Internal.TcpReceiveMessage.datamax := SIZEOF(MessageReceived);  
				Internal.TcpReceiveMessage.flags := 0;
				Internal.TcpReceiveMessage(); 
			
				IF Internal.TcpReceiveMessage.status = ERR_OK THEN  
					// do nothing
				ELSIF Internal.TcpReceiveMessage.status = tcpERR_NO_DATA THEN 
					// do nothing					
				ELSIF Internal.TcpReceiveMessage.status = ERR_FUB_BUSY THEN  			
					// wait					
				ELSIF Internal.TcpReceiveMessage.status = tcpERR_NOT_CONNECTED THEN  			
					Internal.MachineStateStep := 11;
				ELSE  
					StatusID := Internal.TcpReceiveMessage.status;
					Internal.MachineStateStep := 99;
				END_IF
			END_IF
					
		40: // Send Data to the Server	
			StatusID := ERR_FUB_BUSY;
			
			Internal.TcpSendMessage.enable := TRUE;					
			Internal.TcpSendMessage.ident := Internal.SocketID; 
			Internal.TcpSendMessage.pData := ADR(Internal.SendingMessage);  
			Internal.TcpSendMessage.datalen := SIZEOF(Internal.SendingMessage);  								
			Internal.TcpSendMessage.flags := 0;
			Internal.TcpSendMessage();  
				
			IF Internal.TcpSendMessage.status = ERR_OK THEN  
				Internal.LastMessageSent := Internal.SendingMessage;
				Internal.MachineStateStep := 30;
			ELSIF Internal.TcpSendMessage.status = ERR_FUB_BUSY THEN  			
				// wait					
			ELSIF Internal.TcpSendMessage.status = tcpERR_NOT_CONNECTED THEN  			
				Internal.MachineStateStep := 11;
			ELSE  
				StatusID := Internal.TcpSendMessage.status;
				Internal.MachineStateStep := 99;
			END_IF
								
		99: // An error occured -> close connection and go to error state			
			IF Internal.SocketID <> 0 THEN
				Internal.TcpCloseConnection.enable := TRUE;	
				Internal.TcpCloseConnection.ident := Internal.SocketID;  
				Internal.TcpCloseConnection.how := 0;
				Internal.TcpCloseConnection();   
		
				IF Internal.TcpCloseConnection.status <> ERR_FUB_BUSY THEN  	
					Internal.SocketID := 0;
				END_IF
			ELSE
			
				IF Reset AND NOT Internal.Reseted THEN
					Internal.Reseted := TRUE;
					Internal.MachineStateStep := 0;
				END_IF
			END_IF
        
		ELSE
			Internal.MachineStateStep := 0;			
        
	END_CASE
	
	IF NOT Reset THEN
		Internal.Reseted := FALSE;
	END_IF
	
	Active := Internal.MachineStateStep = 30 OR Internal.MachineStateStep = 40;
	Error := Internal.MachineStateStep = 99;
END_ACTION

ACTION TCPChatFBCyclicCode:	
	
	IF Internal.Parameters.ServerRole THEN
		TCPChatFBCyclicServerCode;
	ELSE
		TCPChatFBCyclicClientCode;
	END_IF
	
END_ACTION
    
ACTION TCPChatFBResetInternal:
	
	IF Internal.SocketID <> 0 THEN // An open connection exists -> close it
		Internal.TcpCloseConnection.enable := TRUE;	
		Internal.TcpCloseConnection.ident := Internal.SocketID;  
		Internal.TcpCloseConnection.how := 0;
		Internal.TcpCloseConnection();
		
		IF Internal.TcpCloseConnection.status <> ERR_FUB_BUSY THEN
			Internal.SocketID := 0;
		END_IF
	ELSE
	
		memset(ADR(Internal.Parameters),0,SIZEOF(Internal.Parameters));
		memset(ADR(Internal.SocketIDs),0,SIZEOF(Internal.SocketIDs));
		Internal.Enabled := FALSE;
		Internal.ParametersValid := FALSE;	
		Internal.MachineStateStep := 0;	
		
	END_IF
	
END_ACTION

ACTION TCPChatFBResetOutputs:
	
	Active := FALSE;
	Error := FALSE;
	StatusID := 0;
	MessageReceived := '';
	
END_ACTION