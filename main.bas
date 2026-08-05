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

Type HTTPRequest
    content_length As Long
    method As String
    resource As String
    version As String
    headers(100) As HTTPHeader
    body As String
End Type

Dim Shared As HTTPRequest EmptyReq
Dim Shared As HTTPRequest Req

Sub InspectRequest
    Print "-- Req --"
    Print "  method: " + Req.method
    Print "  resource: " + Req.resource
    Print "  content_length:", Req.content_length
    Print "-- End --"
    Print
End Sub

Type ConfigType
    Port As String
End Type
Dim Shared Config As ConfigType
Config.Port = "8080"

ParseOpts

Dim As Long host, c
Dim dat$, req_line$, resp$
'Dim As Integer ret

host = _OpenHost("TCP/IP:" + Config.Port)

If host = 0 Then
    Print "Could not start server. For some reason. I don't know. Maybe port 8080 is already in use?"
    System
Else
    Print
    Print Time$, "Server waiting on connections."
End If

Do
    c = _OpenConnection(host)

    If c < 0 Then

        Get #c, , dat$

        Req = EmptyReq ' empty the Req

        ' log incoming
        req_line$ = Left$(dat$, InStr(dat$, CRLF) - 1)
        Print Time$ + "  " + _ConnectionAddress(c) + "  " + req_line$;
        Print " (" + _ToStr$(Len(dat$)) + ")"

        ParseRequest c, dat$
        'InspectRequest

        If Req.method = "GET" Then
            GET_Handler c
        End If

        If Req.method = "PUT" Then
            PUT_Handler c
        End If

        If Req.method = "OPTIONS" Then
            resp$ = H_OPTIONS + CRLF
            Put #c, , resp$
            Close #c
        End If

        If Req.method = "HEAD" Then
            resp$ = H_OK + H_CONTENT_TYPE
            resp$ = resp$ + "Content-Length: " + _ToStr$(GetFileLength("." + Req.resource)) + CRLF + CRLF
            Put #c, , resp$
            Close #c
        End If

    End If
    _Limit 12
Loop




Sub ParseRequest (c As Long, dat As String)
    ' todo - should be a function that returns success/failure?

    Dim As String body, top, req_line, headers, method, resource
    Dim As Integer idx, p, i
    Dim As Long cl
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
            lines(idx) = Left$(headers, p - 1)
            idx = idx + 1
            headers = Mid$(headers, p + 2)
        End If
    Wend

    For i = 0 To idx - 1
        'Req.headers(idx) = lines(idx)
        If InStr(1, lines(i), "Content-Length:") > 0 Then
            p = InStr(1, lines(i), ":")
            cl = Val(Mid$(lines(i), p + 1), Long)
            Req.content_length = cl
        End If
    Next

    While Len(body) < Req.content_length
        Get #c, , dat$
        Print "   received", Len(dat$)
        body = body + dat$
    Wend
    Req.body = body

End Sub ' ParseRequest


Function GetFileLength (fname As String)
    Dim f As Long
    If _FileExists(fname) Then
        f = FreeFile
        Open fname For Input As #f
        GetFileLength = LOF(f)
        Close #f
    End If
End Function


Sub GET_Handler (c As Long)
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
        Put #c, , resp
        Put #c, , msg
    End If
    fname = "." + Req.resource
    If _FileExists(fname) Then
        resp = H_OK + H_CONTENT_TYPE
        resp = resp + "Content-Length: " + _ToStr$(GetFileLength(fname)) + CRLF + CRLF
        resp = resp + _ReadFile$(fname)
    Else
        resp = "HTTP/1.1 404 Not Found" + CRLF + CRLF
    End If
    Put #c, , resp
    Close #c
End Sub


Sub PUT_Handler (c As Long)
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
    Put #c, , resp$
    Close #c
    '_writefile "body.html", Req.body
End Sub

Sub ParseOpts
    Dim As Integer i
    Dim As String target
    ' Pass 1
    For i = 0 To _CommandCount
        Select Case Command$(i)
	    case "-h", "--help"
            PrintUsage
            End
	case InStr(Command$(i), "html") Then
            target = Command$(i)
        End If
        If Command$(i) = "-p" Then
            Config.Port = Command$(i + 1)
        End If
	end select
    Next
    ' Pass 2
    For i = 0 To _CommandCount
        Select Case Command$(i)
            Case "-o", "-open", "--open"
                Shell _DontWait _Hide "open http://localhost:" + Config.Port + "/" + target
        End Select
    Next
End Sub

Sub PrintUsage
    Print Command$(0) + ": a sigle-file server for Tiddlywiki."
End Sub

