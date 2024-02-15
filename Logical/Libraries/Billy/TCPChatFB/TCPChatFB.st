FUNCTION_BLOCK TCPChatFB 

	IF Enable THEN     
		
        IF NOT Internal.Enabled OR (Update AND NOT Internal.Updated) THEN 
			TCPChatFBCheckParameters;
		END_IF;
		Internal.Updated := Update;
		
        IF Internal.ParametersValid THEN
            TCPChatFBCyclicCode;
        END_IF;
        
        Internal.Enabled := Enable;		
    ELSE
        TCPChatFBResetInternal;
        TCPChatFBResetOutputs;		
    END_IF;

END_FUNCTION_BLOCK