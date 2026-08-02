FLAGS := -s:ExeWithSource=true

all: server

server: server.bas
	qb64pe -w -x $(FLAGS) $^

.PHONY: clean fmt

clean:
	$(RM) server
	$(RM) *.html

fmt:
	qb64pe -w -y server.bas -o server.bas
