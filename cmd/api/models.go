package api

import (
	"fmt"
)

type PageInfo struct {
	HasNextPage bool
	EndCursor   string
}

type Publisher struct {
	Id   string
	Name string
}

type Repository struct {
	Id        string
	Name      string
	Publisher Publisher
}

type User struct {
	Id        string
	Name      string
	Email     string
	Publisher Publisher
}

type Chart struct {
	Id            string
	Name          string
	Description   string
	LatestVersion string
	Dependencies  Dependencies
}

type ChartInstallation struct {
	Id           string
	Chart        Chart
	Version      Version
	Installation Installation
}

type Tag struct {
	Tag string
}

type Version struct {
	Id             string
	Version        string
	Readme         string
	ValuesTemplate string
}

type Terraform struct {
	Id             string
	Name           string
	Description    string
	ValuesTemplate string
	Dependencies   Dependencies
	Package        string
}

type Dependencies struct {
	Dependencies []Dependency
	Providers    []string
	Wirings      Wirings
}

type Dependency struct {
	Type string
	Repo string
	Name string
}

type Wirings struct {
	Terraform map[string]string
	Helm      map[string]string
}

type TerraformInstallation struct {
	Id           string
	Installation Installation
	Terraform    Terraform
}

type Installation struct {
	Repository Repository
	User       User
	License    string
	Context    map[string]interface{}
}

type InstallationEdge struct {
	Node Installation
}

type ChartEdge struct {
	Node Chart
}

type TerraformEdge struct {
	Node Terraform
}

type VersionEdge struct {
	Node Version
}

type ChartInstallationEdge struct {
	Node ChartInstallation
}

type TerraformInstallationEdge struct {
	Node TerraformInstallation
}

type Token struct {
	Token string
}

type Webhook struct {
	Id     string
	Url    string
	Secret string
}

type Recipe struct {
	Id             string
	Name           string
	RecipeSections []RecipeSection
}

type RecipeSection struct {
	Id          string
	Repository  Repository
	RecipeItems []RecipeItem
}

type RecipeItem struct {
	Id            string
	Terraform     Terraform
	Chart         Chart
	Configuration []ConfigurationItem
}

type ConfigurationItem struct {
	Name    string
	Default string
	Type    string
}

type Artifact struct {
	Id       string
	Name 	   string
	Readme   string
	Blob     string
	Sha      string
	Filesize int
}

const RepositoryFragment = `
	fragment RepositoryFragment on Repository {
		id
		name
		publisher {
			name
		}
	}
`

var InstallationFragment = fmt.Sprintf(`
	fragment InstallationFragment on Installation {
		id
		context
		license
		repository {
			...RepositoryFragment
		}
	}
	%s
`, RepositoryFragment)

const ChartFragment = `
	fragment ChartFragment on Chart {
		id
		name
		description
		latestVersion
	}
`

const VersionFragment = `
	fragment VersionFragment on Version {
		id
		version
		readme
		valuesTemplate
	}
`
const DependenciesFragment = `
	fragment DependenciesFragment on Dependencies {
		dependencies {
			type
			name
			repo
		}
		providers
	}
`

var ChartInstallationFragment = fmt.Sprintf(`
	fragment ChartInstallationFragment on ChartInstallation {
		id
		chart {
			...ChartFragment
			dependencies {
				...DependenciesFragment
			}
		}
		version {
			...VersionFragment
		}
	}
	%s
	%s
	%s
`, ChartFragment, DependenciesFragment, VersionFragment)

var TerraformFragment = fmt.Sprintf(`
	fragment TerraformFragment on Terraform {
		id
		name
		package
		description
		dependencies {
			...DependenciesFragment
			wirings {
				terraform
				helm
			}
		}
		valuesTemplate
	}
	%s
`, DependenciesFragment)

var TerraformInstallationFragment = fmt.Sprintf(`
	fragment TerraformInstallationFragment on TerraformInstallation {
		id
		terraform {
			...TerraformFragment
		}
	}
	%s
`, TerraformFragment)

const TokenFragment = `
	fragment TokenFragment on PersistedToken {
		token
	}
`

const WebhookFragment = `
	fragment WebhookFragment on Webhook {
		id
		url
		secret
	}
`

const ArtifactFragment = `
	fragment ArtifactFragment on Artifact {
		id
		name
		readme
		blob
		sha
		filesize
	}
`