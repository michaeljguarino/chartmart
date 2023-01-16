import { ApolloClient } from '@apollo/client'
import {
  AppsIcon,
  InstallIcon,
  WizardInstaller,
  WizardPicker,
  WizardStepConfig,
} from '@pluralsh/design-system'

import { Provider, Recipe, RecipeSection } from '../../../../../generated/graphql'
import { RECIPES_QUERY } from '../../../../repository/queries'
import { RECIPE_Q } from '../../../../repos/queries'

import { Application } from './Application'

const FORCED_APPS = ['console']

const toPickerItems = (applications, provider: Provider): Array<WizardStepConfig> => applications?.map(app => ({
  key: app.id,
  label: app.name,
  imageUrl: app.icon,
  node: <Application
    key={app.id}
    provider={provider}
  />,
})) || []

const toDefaultSteps = (applications, provider: Provider): Array<WizardStepConfig> => [{
  key: 'apps',
  label: 'Apps',
  Icon: AppsIcon,
  node: <WizardPicker
    items={toPickerItems(applications, provider)}
    preSelected={FORCED_APPS}
  />,
  isDefault: true,
},
{
  key: 'placeholder',
  isPlaceholder: true,
},
{
  key: 'install',
  label: 'Install',
  Icon: InstallIcon,
  node: <WizardInstaller />,
  isDefault: true,
}]

const toDependencySteps = (applications: {section: RecipeSection, dependencyOf: Set<string>}[], provider: Provider): Array<WizardStepConfig> => [...applications.map(app => ({
  key: app.section.repository!.id,
  label: app.section.repository!.name,
  imageUrl: app.section.repository!.icon!,
  node: <Application
    key={app.section.repository!.id}
    provider={provider}
  />,
  isDependency: true,
  dependencyOf: app.dependencyOf,
}))]

const buildSteps = async (client: ApolloClient<unknown>, provider: Provider, selectedApplications: Array<WizardStepConfig>) => {
  const dependencyMap = new Map<string, {section: RecipeSection, dependencyOf: Set<string>}>()

  for (const app of selectedApplications) {
    const { data: { recipes: { edges } = { edges: undefined } } = {} } = await client.query({
      query: RECIPES_QUERY,
      variables: { repositoryId: app.key },
    })

    const { node: recipeBase } = edges?.find(({ node }) => node.provider === provider) || { node: undefined }

    if (!recipeBase) continue

    const { data: recipe } = await client.query<{recipe: Recipe}>({
      query: RECIPE_Q,
      variables: { id: recipeBase?.id },
    })

    const sections = recipe.recipe.recipeSections!.filter(section => section!.repository!.name !== app.label)

    sections.forEach(section => {
      if (selectedApplications.find(app => app.key === section!.repository!.id)) return

      if (!dependencyMap.has(section!.repository!.name)) {
        dependencyMap.set(section!.repository!.name, { section: section!, dependencyOf: new Set([app.label!]) })

        return
      }

      const dep = dependencyMap.get(section!.repository!.name)!
      const dependencyOf: Array<string> = [...Array.from(dep.dependencyOf.values()), app.label!]

      dependencyMap.set(section!.repository!.name, { section: section!, dependencyOf: new Set<string>(dependencyOf) })
    })
  }

  return toDependencySteps(Array.from(dependencyMap.values()), provider)
}

export {
  toDependencySteps, toDefaultSteps, buildSteps, toPickerItems,
}
