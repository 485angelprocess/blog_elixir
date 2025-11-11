"""
Migrate files from older blog post
"""
from mrkdwn_analysis import MarkdownAnalyzer
import json
import argparse
import os
import datetime

def get_files(path):
    return [os.path.join(dp, f) for dp, dn, filenames in os.walk(path) for f in filenames if os.path.splitext(f)[1] == '.md']

class FileMigration(object):
    def __init__(
        self,
        filename,
        output_folder,
        existing      
    ):
        self.filename = filename
        self.output_folder = output_folder
        self.existing = existing
        self.analyzer = self.analyze()

    def already_in_output(self):
        basename = os.path.basename(self.filename)
        return any([p.endswith(basename) for p in self.existing])
        
    def analyze(self):
        return MarkdownAnalyzer(self.filename)

    def get_title(self):
        headers = self.analyzer.identify_headers()

        title = headers["Header"][0]["text"]

        return title

    def _user_input(self, msg, default):
        val = input("{} [{}]: ".format(msg, default))

        if len(val) == 0:
            return default
        else:
            return val

    def set_title(self):
        self.title = self._user_input("Title", self.get_title())

    def set_date(self):
        timec = os.path.getctime(self.filename)

        dt = datetime.datetime.fromtimestamp(timec)
        
        self.month = int(self._user_input("Month", dt.month))
        self.day = int(self._user_input("Day", dt.day))
        self.year = 2025

    def set_tags(self):
        self.tags = list()
        
        while True:
            val = input("tag: ")
            if len(val) == 0:
                print("Tags: {}".format(self.tags))
                return
            else:
                self.tags.append(val.strip())

    def set_description(self):
        self.description = input("Description: ")


    def set_data(self):
        self.set_title()
        self.set_date()
        self.set_tags()
        self.set_description()

    def get_meta(self):
        yield "%{"
        yield '\ttitle: "{}",'.format(self.title)
        yield '\tauthor: "Annabelle Adelaide",'
        yield '\ttags: ~w({}),'.format(",".join(self.tags))
        yield '\tdescription: "{}"'.format(self.description)
        yield "}"
        yield "---"

    def migrate(self):
        ok = input("Load {}? [yN]: ".format(self.get_title()))
        if ok == 'y':
            self.set_data()
            output_dir = "{}".format(self.year)
            basename = os.path.basename(self.filename)
            output_file = "{:02}-{:02}-{}".format(self.month, self.day, basename)

            out = os.path.join(self.output_folder, output_dir, output_file)

            with open(out, 'w') as f:
                for m in self.get_meta():
                    f.write(m)
                    f.write("\n")
                with open(self.filename, 'r') as fr:
                    for l in fr.readlines():
                        f.write(l)
                

if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Blog Post migrater", description="Migrates old blog posts, fixes links")

    parser.add_argument("dir", help="Base path of file")

    args = parser.parse_args()

    output = "../posts/"

    existing = list(get_files(output))

    print("Existing posts: {}".format(existing))
    for post in get_files(args.dir):
        if post.endswith(".md"):
            print("Loading post: {}".format(post))
            fm = FileMigration(post, output, existing)
    
            fm.migrate()
