#!/usr/bin/env python3

import os,sys
import xml.etree.ElementTree as ET
import json
import uuid

def parse_xml_to_dict(xml_string):
    root = ET.fromstring(xml_string)
    result = {}
    for folder_elem in root.findall('folder'):
        folder_title = folder_elem.find('title').text
        snippets = []
        for snippet_elem in folder_elem.findall('snippets/snippet'):
            snippet_title = snippet_elem.find('title').text
            snippet_content = snippet_elem.find('content').text
            snippet = {'title': snippet_title, 'content': snippet_content}
            snippets.append(snippet)
        result[folder_title] = snippets
    return result

def translate_to_new_format(cont):
    new_content = []
    folder_idx = 0
    for title, snippets in cont.items():
        folder_uuid = str(uuid.uuid4())
        folder = {'title':title, 'index':folder_idx, 'enable':True, 'identifier':folder_uuid}
        snippet_idx = 0
        for snippet in snippets:
            snippet['index'] = snippet_idx
            snippet['enable'] = True
            snippet['identifier'] = str(uuid.uuid4())
            if snippet.get('content') is None:
                snippet['content'] = ''
            if snippet.get('title') is None:
                snippet['title'] = ''
            snippet_idx += 1
        folder['snippets'] = snippets
        new_content.append(folder)
        folder_idx += 1
    return new_content

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.realpath(__file__)))

    if len(sys.argv) > 1:
        path = sys.argv[1]
        with open(path, 'r') as rf:
            content = parse_xml_to_dict(rf.read().strip())
            content = translate_to_new_format(content)
            with open('snippets.json', 'w') as wf:
                json.dump(content, wf)






