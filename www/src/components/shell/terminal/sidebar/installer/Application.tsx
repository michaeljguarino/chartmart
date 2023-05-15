import { useQuery } from '@apollo/client'
import {
  Chip,
  LoopingLogo,
  WizardStep,
  useActive,
} from '@pluralsh/design-system'
import { Box } from 'grommet'
import { Div, Span } from 'honorable'
import { ReactElement, useContext, useEffect, useMemo, useState } from 'react'

import { Provider, Recipe, RecipeEdge } from '../../../../../generated/graphql'
import { RECIPE_Q } from '../../../../repository/packages/queries'

import { RECIPES_QUERY } from '../../../../repository/queries'
import { TerminalContext } from '../../context/terminal'

import { Configuration } from './Configuration'

interface StepData {
  id: string | undefined
  context: Record<string, unknown>
  oidc: boolean
  skipped?: boolean
}

const toConfig = (config) =>
  config
    ? Object.keys(config)
        .map((key) => ({ [key]: { value: config[key], valid: true } }))
        .reduce((acc, entry) => ({ ...acc, ...entry }), {})
    : undefined

const findRecipe = (
  recipes: Array<RecipeEdge>,
  primary: boolean,
  provider: Provider
): Recipe | undefined =>
  recipes === undefined
    ? undefined
    : (recipes
        .map(({ node }) => node)
        .find((recipe) =>
          primary
            ? recipe!.provider === provider && recipe!.primary
            : recipe!.provider === provider
        ) as Recipe)

export function Application({ provider, ...props }: any): ReactElement {
  const { active, setData } = useActive<StepData>()
  const { configuration } = useContext(TerminalContext)
  const [context, setContext] = useState<Record<string, unknown>>(
    active.data?.context || {}
  )
  const [valid, setValid] = useState(true)
  const [oidc, setOIDC] = useState(active.data?.oidc ?? true)
  const {
    data: { recipes: { edges: recipeEdges } = { edges: undefined } } = {},
  } = useQuery(RECIPES_QUERY, {
    variables: { repositoryId: active.key },
  })

  let recipeBase = findRecipe(recipeEdges, true, provider)

  // A fallback in case there are no primary recipes for given application
  if (!recipeBase) {
    recipeBase = findRecipe(recipeEdges, false, provider)
  }

  const { data: recipe } = useQuery<{ recipe: Recipe }>(RECIPE_Q, {
    variables: { id: recipeBase?.id },
    skip: !recipeBase,
  })

  const recipeContext = useMemo(
    () => toConfig(configuration?.contextConfiguration![active.label!]),
    [active.label, configuration?.contextConfiguration]
  )
  const mergedContext = useMemo<Record<string, unknown>>(
    () => ({ ...recipeContext, ...context }),
    [recipeContext, context]
  )
  const stepData = useMemo(
    () => ({
      ...active.data,
      ...{ id: recipe?.recipe.id },
      ...{ context: mergedContext },
      ...{ oidc },
    }),
    [active.data, recipe?.recipe.id, mergedContext, oidc]
  )

  useEffect(() => {
    const valid = Object.values<any>(context).every(({ valid }) => valid)

    setValid(valid)
  }, [context, setValid])

  // Update step data on change
  useEffect(() => setData(stepData), [stepData, setData])

  if (!recipe) {
    return (
      <WizardStep {...props}>
        <Box
          overflow="hidden"
          fill="vertical"
          justify="center"
        >
          {/* @ts-expect-error */}
          <LoopingLogo overflow="hidden" />
        </Box>
      </WizardStep>
    )
  }

  if (recipe.recipe?.restricted) {
    return (
      <WizardStep
        valid={false}
        {...props}
      >
        <Div
          marginTop="xxsmall"
          marginBottom="medium"
          display="flex"
          gap="medium"
          flexDirection="column"
        >
          <Span
            color="text-xlight"
            overline
          >
            Cannot install app
          </Span>
          <Span
            color="text-light"
            body2
          >
            This application has been marked restricted because it requires
            configuration, like ssh keys, that are only able to be securely
            configured locally.
          </Span>
        </Div>
      </WizardStep>
    )
  }

  return (
    <WizardStep
      valid={valid}
      data={stepData}
      {...props}
    >
      <Div
        marginBottom="medium"
        display="flex"
        lineHeight="24px"
        alignItems="center"
        height="24px"
      >
        <Span
          overline
          color="text-xlight"
        >
          configure {active.label}
        </Span>
        {active.isDependency && (
          <Chip
            size="small"
            hue="lighter"
            marginLeft="xsmall"
          >
            Dependency
          </Chip>
        )}
      </Div>
      <Configuration
        recipe={recipe.recipe}
        context={mergedContext}
        setContext={setContext}
        oidc={oidc}
        setOIDC={setOIDC}
      />
    </WizardStep>
  )
}
