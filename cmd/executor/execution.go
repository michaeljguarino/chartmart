package executor

import (
	"fmt"
	"io/ioutil"
	"path/filepath"
	"strings"

	"github.com/hashicorp/hcl"
	"github.com/michaeljguarino/forge/utils"
	"github.com/rodaine/hclencoder"
)

type Execution struct {
	Metadata Metadata `hcl:"metadata"`
	Steps    []*Step  `hcl:"step"`
}

type Metadata struct {
	Path string `hcl:"path"`
	Name string `hcl:"name"`
}

const (
	forgeIgnore = `terraform/.terraform`
)

func Ignore(root string) error {
	ignoreFile := filepath.Join(root, ".forgeignore")
	return ioutil.WriteFile(ignoreFile, []byte(forgeIgnore), 0644)
}

func GetExecution(path, name string) (*Execution, error) {
	fullpath := filepath.Join(path, name+".hcl")
	contents, err := ioutil.ReadFile(fullpath)
	ex := Execution{}
	if err != nil {
		return &ex, err
	}

	err = hcl.Decode(&ex, string(contents))
	if err != nil {
		return &ex, err
	}

	return &ex, nil
}

func (e *Execution) Execute() error {
	root, err := utils.RepoRoot()
	if err != nil {
		return err
	}
	ignore, err := e.IgnoreFile(root)

	fmt.Printf("deploying %s, hold on to your butts\n", e.Metadata.Path)
	for i, step := range e.Steps {
		newSha, err := step.Execute(root, ignore)
		if err != nil {
			if err := e.Flush(root); err != nil {
				return err
			}

			return err
		}

		e.Steps[i].Sha = newSha
	}

	return e.Flush(root)
}

func (e *Execution) IgnoreFile(root string) ([]string, error) {
	ignorePath := filepath.Join(root, e.Metadata.Path, ".forgeignore")
	contents, err := ioutil.ReadFile(ignorePath)
	if err != nil {
		return []string{}, err
	}

	ignore := strings.Split(string(contents), "\n")
	result := []string{}
	for _, prefix := range ignore {
		ignoreStr := strings.TrimSpace(prefix)
		if ignoreStr != "" {
			result = append(result, ignoreStr)
		}
	}

	return result, nil
}

func DefaultExecution(path string, prev *Execution) (e *Execution) {
	byName := make(map[string]*Step)
	steps := []*Step{
		{
			Name:    "terraform-init",
			Wkdir:   filepath.Join(path, "terraform"),
			Target:  filepath.Join(path, "terraform"),
			Command: "terraform",
			Args:    []string{"init"},
			Sha:     "",
		},
		{
			Name:    "terraform-apply",
			Wkdir:   filepath.Join(path, "terraform"),
			Target:  filepath.Join(path, "terraform"),
			Command: "terraform",
			Args:    []string{"apply", "-auto-approve"},
			Sha:     "",
		},
		{
			Name:    "kube-init",
			Wkdir:   path,
			Target:  forgefile(path, "NONCE"),
			Command: "forge",
			Args:    []string{"wkspace", "kube-init", path},
			Sha:     "",
		},
		{
			Name:    "helm-init",
			Wkdir:   path,
			Target:  forgefile(path, "ONCE"),
			Command: "forge",
			Args:    []string{"wkspace", "helm-init", path},
			Sha:     "",
		},
		{
			Name:    "docker-credentials",
			Wkdir:   path,
			Target:  forgefile(path, "ONCE"),
			Command: "forge",
			Args:    []string{"wkspace", "docker-credentials", path},
			Sha:     "",
		},
		{
			Name:    "bounce",
			Wkdir:   path,
			Target:  filepath.Join(path, "helm"),
			Command: "forge",
			Args:    []string{"wkspace", "helm", path},
			Sha:     "",
		},
	}

	for _, step := range steps {
		byName[step.Name] = step
	}

	finalizedSteps := []*Step{}
	for _, step := range prev.Steps {
		if val, ok := byName[step.Name]; ok {
			val.Sha = step.Sha
			delete(byName, step.Name)
			finalizedSteps = append(finalizedSteps, val)
		} else {
			finalizedSteps = append(finalizedSteps, step)
		}
	}

	for _, step := range steps {
		if _, ok := byName[step.Name]; ok {
			finalizedSteps = append(finalizedSteps, step)
		}
	}

	return &Execution{
		Metadata: Metadata{Path: path, Name: "deploy"},
		Steps:    finalizedSteps,
	}
}

func (e *Execution) Flush(root string) error {
	io, err := hclencoder.Encode(&e)
	if err != nil {
		return err
	}

	path, _ := filepath.Abs(filepath.Join(root, e.Metadata.Path, e.Metadata.Name+".hcl"))
	return ioutil.WriteFile(path, io, 0644)
}

func forgefile(base, name string) string {
	return filepath.Join(base, ".forge", name)
}
