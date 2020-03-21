#!/usr/bin/env python3

import cgi

print('HTTP/1.0 200 OK')
print('Content-Type: text/html')
print()

form = cgi.FieldStorage()

if 'user' in form:
    print('<h1>Hello, {}</h1>'.format(form['user'].value))

print('''
<form>
    <input type="text" name="user">
    <input type="submit">
</form>
''')
