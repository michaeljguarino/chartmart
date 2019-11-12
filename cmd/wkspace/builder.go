package wkspace

import (
	"os"
	"path"
	"path/filepath"
	"github.com/michaeljguarino/chartmart/api"
)

type Workspace struct {
	Installation *api.Installation
	Charts []api.ChartInstallation
	Terraform []api.TerraformInstallation
}

func New(client *api.Client, inst *api.Installation) (*Workspace, error) {
	ci, err := client.GetChartInstallations(inst.Repository.Id)
	ti, err2 := client.GetTerraformInstallations(inst.Repository.Id)
	var anyErr error
	if err != nil {
		anyErr = err
	} else if err2 != nil {
		anyErr = err2
	}

	return &Workspace{inst, ci, ti}, anyErr
}

func (wk *Workspace) Prepare() error {
	repo := wk.Installation.Repository
	if err := mkDir(repo.Name, "terraform"); err != nil {
		return err
	}
	if err := mkDir(repo.Name, "helm"); err != nil {
		return err
	}

	manifest := wk.BuildManifest()
	manifestPath, _ := filepath.Abs(path.Join(repo.Name, "manifest.yaml"))
	if err := manifest.Write(manifestPath); err != nil {
		return err
	}

	if err := wk.BuildHelm(); err != nil {
		return err
	}

	if err := wk.BuildTerraform(); err != nil {
		return err
	}

	return nil
}

func mkDir(repoName, subDir string) error {
	path, err := filepath.Abs(path.Join(repoName, subDir))
	if err != nil {
		return err
	}
	if err := os.MkdirAll(path, os.ModePerm); err != nil {
		return err
	}
	return nil
}