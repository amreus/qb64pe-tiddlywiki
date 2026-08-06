$Console:Only
Option _Explicit

ChDir _StartDir$

Const CRLF = Chr$(13) + Chr$(10)
Const H_OK = "HTTP/1.1 200 OK" + CRLF
Const H_CONTENT_TYPE = "Content-Type: text/html" + CRLF
Const H_CONTENT_LENGTH_0 = "Content-Length: 0" + CRLF
Const H_OPTIONS = H_OK + H_CONTENT_LENGTH_0 + "Allow: OPTIONS, GET, HEAD, PUT" + CRLF + "Dav: tw-put" + CRLF

Type HTTPHeader
    name As String
    value As String
End Type

Dim Shared EmptyHeader As HTTPHeader

Type HTTPRequest
    content_length As Long
    method As String
    resource As String
    version As String
    headers(64) As HTTPHeader
    header_count As Integer
    body As String
End Type

Dim Shared As HTTPRequest EmptyReq
Dim Shared As HTTPRequest Req

Sub InspectRequest
    Dim As Integer i
    Print "-- Req --"
    Print "  method: " + Req.method
    Print "  resource: " + Req.resource
    Print "  content_length:", Req.content_length
    Print "  header_count:", Req.header_count
    For i = 0 To Req.header_count - 1
        Print Using "    \                    \ &"; Req.headers(i).name; Req.headers(i).value
    Next
    Print "-- End --"
    Print
End Sub

Type ConfigType
    Port As String
    target As String
End Type
Dim Shared Config As ConfigType
Config.Port = "8080"

ParseOpts

Dim As Long host, client
Dim dat$, req_line$, resp$
'Dim As Integer ret


host = _OpenHost("TCP/IP:" + Config.Port)

If host = 0 Then
    Print "Could not start server for some reason I don't know. Exiting."
    System
Else
    Print
    Print Date$, Time$, "Server waiting on clients at http://localhost:" + Config.Port + "/" + Config.target
End If

Do
    client = _OpenConnection(host)

    If client < 0 Then

        Get #client, , dat$

        Req = EmptyReq ' empty the Req

        ' log incoming
        req_line$ = Left$(dat$, InStr(dat$, CRLF) - 1)
        Print Date$, Time$ + "  " + _ConnectionAddress(client) + "  " + req_line$;
        Print " (" + _ToStr$(Len(dat$)) + ")"

        ParseRequest client, dat$
        'InspectRequest

        If Req.method = "GET" Then
            GET_Handler client
        End If

        If Req.method = "PUT" Then
            PUT_Handler client
        End If

        If Req.method = "OPTIONS" Then
            resp$ = H_OPTIONS + CRLF
            Put #client, , resp$
            Close #client
        End If

        If Req.method = "HEAD" Then
            resp$ = H_OK + H_CONTENT_TYPE
            resp$ = resp$ + "Content-Length: " + _ToStr$(GetFileLength("." + Req.resource)) + CRLF + CRLF
            Put #client, , resp$
            Close #client
        End If

    End If
    _Limit 12
Loop




Sub ParseRequest (client As Long, dat As String)
    ' todo - should be a function that returns success/failure?

    Dim As String body, top, req_line, headers, method, resource, header_line
    Dim As Integer idx, p, q
    Dim header As HTTPHeader
    ReDim lines(100) As String

    top = Left$(dat, InStr(dat, CRLF + CRLF) + 2) ' leave a CRLF at the end for later
    body = Mid$(dat, InStr(dat, CRLF + CRLF) + 4)

    req_line = Left$(top, InStr(top, CRLF) - 1)
    p = InStr(1, req_line, " ")
    method = Left$(req_line, p - 1)
    Req.method = method
    resource = Mid$(req_line, p + 1, InStr(p + 1, req_line, " ") - p - 1)
    Req.resource = resource
    headers = Mid$(top, InStr(top, CRLF) + 2)

    While Len(headers) > 2 ' here we need that CRLF from earlier...
        p = InStr(headers, CRLF)
        If p Then
            header = EmptyHeader
            header_line = Left$(headers, p - 1)
            lines(idx) = header_line
            q = InStr(header_line, ":")
            header.name = Left$(header_line, q - 1)
            header.value = _Trim$(Mid$(header_line, q + 1))
            Req.headers(idx) = header
            Inc idx
            Inc Req.header_count
            headers = Mid$(headers, p + 2)
        End If
    Wend

    Req.content_length = Val(Request_getHeader$("Content-Length"), Long)

    While Len(body) < Req.content_length
        Get #client, , dat$
        Print "   received", Len(dat$)
        body = body + dat$
    Wend
    Req.body = body

End Sub ' ParseRequest

Function Request_getHeader$ (header_name As String)
    Dim As Integer i
    For i = 0 To Req.header_count - 1
        If Req.headers(i).name = header_name Then
            Request_getHeader$ = Req.headers(i).value
        End If
    Next
End Function


Function GetFileLength (fname As String)
    Dim f As Long
    If _FileExists(fname) Then
        f = FreeFile
        Open fname For Input As #f
        GetFileLength = LOF(f)
        Close #f
    End If
End Function


Sub GET_Handler (client As Long)
    Dim As String fname, resp, msg
    If Req.resource = "/" Then
        fname = _Files$("*.htm*")
        msg = "<ul>"
        While fname <> ""
            msg = msg + "<li> <a href='" + fname + "'>" + fname + "</a></li>"
            fname = _Files$
        Wend
        msg = msg + "</ul>"
        resp = H_OK + H_CONTENT_TYPE
        resp = resp + "Content-Length: " + _ToStr$(Len(msg)) + CRLF + CRLF
        Put #client, , resp
        Put #client, , msg
    End If
    fname = "." + Req.resource
    If _FileExists(fname) Then
        resp = H_OK + H_CONTENT_TYPE
        resp = resp + "Content-Length: " + _ToStr$(GetFileLength(fname)) + CRLF + CRLF
        resp = resp + _ReadFile$(fname)
    Else
        resp = "HTTP/1.1 404 Not Found" + CRLF + CRLF
    End If
    Put #client, , resp
    Close #client
End Sub


Sub PUT_Handler (client As Long)
    Dim resp$
    Dim As String fname
    Dim As Long body_len
    body_len = Len(Req.body)
    fname = "." + Req.resource
    If body_len <> Req.content_length Then
        Print "LENGTHS DO NOT MATCH. Not saving.."
        resp$ = "HTTP/1.1 500 Internal Server Error"
    Else
        _WriteFile fname, Req.body
        Print "   wrote " + _ToStr$(body_len) + " bytes to " + fname + "."
        resp$ = "HTTP/1.1 201 Created" + CRLF
    End If
    Put #client, , resp$
    Close #client
    '_writefile "body.html", Req.body
End Sub


Sub ParseOpts
    Dim As Integer i
    ' Pass 1 - set options
    For i = 0 To _CommandCount
        Select Case Command$(i)
            Case "-h", "--help"
                PrintUsage
                System
            Case "-p"
                If PortValid(Command$(i + 1)) Then
                    Config.Port = Command$(i + 1)
                Else
                    PrintUsage
                    System
                End If
        End Select
        If InStr(Command$(i), "html") Then
            Config.target = Command$(i)
        End If
    Next
    ' Pass 2
    For i = 0 To _CommandCount
        Select Case Command$(i)
            Case "-o", "-open", "--open"
                Shell _DontWait _Hide "open http://localhost:" + Config.Port + "/" + Config.target
        End Select
    Next
End Sub


Function PortValid (port As String)
    Dim As Integer p, ret
    p = Val(port, Integer)
    If p _AndAlso p > 1024 Then
        ret = _TRUE
    Else
        Print "Invalid port: " + port
    End If
    PortValid = ret
End Function


Sub PrintUsage
    Print
    Print Command$(0) + ": a sigle-file server for Tiddlywiki."
    Print
    Print "Usage: ./server [-p port] [-o] [file.html]"
    Print Chr$(9) + "-p port - the port number to use for the host. Defaults to 8080."
    Print Chr$(9) + "-o - open a browser window."
    Print Chr$(9) + "file.html - a TiddlyWiki file to serve."
End Sub


Sub Inc (n As Integer)
    n = n + 1
End Sub
