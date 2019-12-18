# protocol overview

1. AUTHENTICATION: authentication message and informations about messages to transfer
2. RESPONSE: OK or ERROR
3. loop:
	- TRANSFER: message id, file chunk
	- REPONSE: Ok

# messages content

format: IPC USER MESSAGE TYPE, JSON ENCODED MESSAGE

1. AUTHENTICATION message

		1, { message-id: "UUID", token: "JWT", files: [
				{ name: "NAME", size: SIZE-IN-BYTES (unsigned int 64 bits) },
				{ name: "NAME", size: SIZE-IN-BYTES (unsigned int 64 bits) },
			], fid: "UUID", tags: [ TAG-NAME, TAG-NAME ]
		}

	note: The server knows the user id from the token (JWT) and stores the received files in a
2. RESPONSE message

	    2, { message-id: "UUID", response: "Ok" }

	    or

	    2, { message-id: "UUID", response: "Error", reason: "REASON" }

3. TRANSFER message

		3, { message-id: "UUID", chunk: "UUID", data: [ BINARY DATA ] }

# Rationale

### Why don't we just trust TCP to carry the whole file?
The application layer has to know which parts are missing so we can transfer them later (in another connection, maybe).

### Why message id?
The client and the server do not have a direct TCP connection together, there may be proxies.
The client cannot trust its TCP connection to know exactly what are the parts the server really got.
The file server to proxy connection can be dropped, we have to ensure the communication between the client and the server.


# How this works:

* libipc is used to communicate
* dodb is used to keep track of the files, using its tag system
* messages are: JSON encoded, 1KB buffered data
* message example: { message-id: "UUID", chunk: "UUID", data: [1KB BINARY DATA] }
