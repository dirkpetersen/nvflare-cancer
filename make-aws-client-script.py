#! /usr/bin/env python3

import os, sys 
from nvflare.lighter import tplt_utils, utils

client = "AWS-T4"
org = "Test"

lighter_folder = os.path.dirname(utils.__file__)
template = utils.load_yaml(os.path.join(lighter_folder, "impl", "master_template.yml"))
template.update(utils.load_yaml(os.path.join(lighter_folder, "impl", "aws_template.yml")))
tplt = tplt_utils.Template(template)
csp = 'aws'
if len(sys.argv) > 1:
    dest = sys.argv[1]
else:
    dest = os.path.join(os.getcwd(), f"{csp}_start.sh")
script = template[f"cloud_script_header"] + template[f"{csp}_start_sh"]
script = utils.sh_replace(
            script, {"type": "client", "inbound_rule": "", "cln_uid": f"uid={client}", "ORG": org}
        )
utils._write(
    dest,
    script,
     "t",
     exe=True,
)
print(f"Script written to {dest} !")
