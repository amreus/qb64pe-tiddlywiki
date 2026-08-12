# $@ - The file name of the target of the rule.
# $< - The name of the first prerequisite.
# $^ - The names of all the prerequisites , with spaces between.

FLAGS := -s:ExeWithSource=true

TARGET := tws


$(TARGET): main.bas
	qb64pe -w -x $(FLAGS) $< -o $@


empty.html:
	curl https://tiddlywiki.com/empty.html > empty.html


.PHONY: clean fmt install

fmt:
	qb64pe -w -y main.bas -o main.bas

clean:
	$(RM) $(TARGET)

install: $(TARGET)
	cp $(TARGET) ~/bin/$(TARGET)

