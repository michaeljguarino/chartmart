package template

import (
	"github.com/michaeljguarino/chartmart/utils"
	"github.com/Masterminds/sprig"
	"io"
	"text/template"
)

func MakeTemplate(tmplate string) (*template.Template, error) {
	funcs := sprig.TxtFuncMap()
	funcs["genAESKey"]       = utils.GenAESKey
	funcs["repoRoot"]        = repoRoot
	funcs["repoName"]        = repoName
	funcs["repoUrl"]         = repoUrl
	funcs["createWebhook"]   = createWebhook
	funcs["dumpConfig"]      = dumpConfig
	funcs["dumpAesKey"]      = dumpAesKey
	funcs["readLine"]        = readLine
	funcs["readLineDefault"] = readLineDefault
	funcs["readFile"] 		   = utils.ReadFile
	funcs["homeDir"]				 = homeDir
	return template.New("gotpl").Funcs(funcs).Parse(tmplate)
}

func RenderTemplate(wr io.Writer, tmplate string, ctx map[string]interface{}) error {
	tmpl, err := MakeTemplate(tmplate)
	if err != nil {
		return err
	}
	return tmpl.Execute(wr, map[string]interface{}{"Values": ctx})
}
