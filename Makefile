FLAGS := -s:ExeWithSource=true

all: server empty.html

server: server.bas
	qb64pe -w -x $(FLAGS) $^


empty.html:
	curl https://tiddlywiki.com/empty.html > empty.html

.PHONY: clean fmt

clean:
	$(RM) server
	$(RM) *.html

fmt:
	qb64pe -w -y server.bas -o server.bas
