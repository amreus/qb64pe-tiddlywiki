$Console:Only
Option _Explicit

Const CRLF = Chr$(13) + Chr$(10)
Const H_OK = "HTTP/1.1 200 OK" + CRLF
Const H_CONTENT_TYPE = "Content-Type: text/html" + CRLF
Const H_CONTENT_LENGTH_0 = "Content-Length: 0" + CRLF
Const H_OPTIONS = H_OK + H_CONTENT_LENGTH_0 + "Allow: OPTIONS, GET, HEAD, PUT" + CRLF + "Dav: tw-put" + CRLF + CRLF

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
End Sub


Dim As Long host, c
Dim dat$, req_line$, resp$
'Dim As Integer ret

host = _OpenHost("TCP/IP:8080")

If host = 0 Then
    Print "Could not start server."
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
        ParseRequest dat$

        req_line$ = Left$(dat$, InStr(dat$, CRLF) - 1)
        Print Time$ + " " + _ConnectionAddress(c) + " " + req_line$;
        Print " (" + _ToStr$(Len(dat$)) + ")"
        'InspectRequest

        If InStr(dat$, "GET") = 1 Then
            GET_Handler c
        End If

        If InStr(dat$, "OPTIONS") = 1 Then
            resp$ = H_OPTIONS
            Put #c, , resp$
            Close #c
        End If

        If InStr(dat$, "PUT") = 1 Then
            PUT_Handler c, dat$
        End If

        If InStr(dat$, "HEAD") = 1 Then
            resp$ = H_OK + H_CONTENT_TYPE
            resp$ = resp$ + "Content-Length: " + _ToStr$(GetFileLength("empty.html")) + CRLF + CRLF
            Put #c, , resp$
            Close #c
        End If

    End If
    _Limit 12
Loop




Sub ParseRequest (dat As String)

    ' todo - should be a function that returns success/failure

    Dim As String body, top, req_line, headers, method, resource
    Dim As Integer idx, p, i
    Dim As Long cl
    ReDim lines(100) As String

    top = Left$(dat, InStr(dat, CRLF + CRLF) + 2) ' leave a CRLF at the end for later
    body = Mid$(dat, InStr(dat, CRLF + CRLF) + 4)

    req_line = Left$(top, InStr(top, CRLF) - 1)
    p = InStr(1, req_line, " ")
    method = Left$(req_line, p - 1)
    'Print "method: '" + method + "'"
    Req.method = method
    resource = Mid$(req_line, p + 1, InStr(p + 1, req_line, " ") - p - 1)
    'Print "resource: '" + resource + "'"
    Req.resource = resource
    headers = Mid$(top, InStr(top, CRLF) + 2)
    'p = InStr(p + 1, req_line, " ")

    While Len(headers) > 2 ' we need that CRLF from earlier...
        p = InStr(headers, CRLF)
        If p Then
            lines(idx) = Left$(headers, p - 1)
            headers = Mid$(headers, p + 2)
            idx = idx + 1
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

End Sub ' ParseRequest


Function GetFileLength (fname As String)
    Dim f As Long
    f = FreeFile
    Open fname For Input As #f
    GetFileLength = LOF(f)
    Close #f
End Function


Sub GET_Handler (c As Long)
    Dim As String resp
    resp = H_OK + H_CONTENT_TYPE
    resp = resp + "Content-Length: " + _ToStr$(GetFileLength("empty.html")) + CRLF + CRLF
    resp = resp + _ReadFile$("empty.html")
    Put #c, , resp
    Close #c
End Sub


Sub PUT_Handler (c As Long, dat$)
    Dim buffer$, resp$
    While Len(dat$) > 0
        buffer$ = buffer$ + dat$
        Get #c, , dat$
        'If Len(dat$) > 0 Then
        '    Print "  recd more data: " + _ToStr$(Len(dat$))
        'End If
    Wend
    'Print "total buffer length: " + _ToStr$(Len(buffer$))
    buffer$ = Mid$(buffer$, InStr(buffer$, CRLF + CRLF) + 4)
    If Len(buffer$) <> Req.content_length Then
        Print "LENGTHS DO NOT MATCH. Not saving.."
        resp$ = "HTTP/1.1 500 Internal Server Error"
    Else
        _WriteFile "empty.html", buffer$
        Print "  wrote " + _ToStr$(Len(buffer$)) + " bytes."
        resp$ = "HTTP/1.1 201 Created" + CRLF
    End If
    Put #c, , resp$
    Close #c
End Sub

