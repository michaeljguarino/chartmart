import { gql } from '@apollo/client'

import { PublisherFragment, UserFragment } from './user'

export const CategoryFragment = gql`
  fragment CategoryFragment on CategoryInfo {
    category
    count
  }
`

export const RepoFragment = gql`
  fragment RepoFragment on Repository {
    id
    name
    description
    releaseStatus
    documentation
    icon
    darkIcon
    private
    trending
    verified
    category
    oauthSettings { uriFormat authMethod }
    publisher { ...PublisherFragment }
  }
  ${PublisherFragment}
`

export const StackFragment = gql`
  fragment StackFragment on Stack {
    id
    name
    displayName
    description
    featured
    creator { 
      id
      name
    }
    collections {
      id
      provider
      bundles {
        recipe {
          repository {
            ...RepoFragment
            tags {
              tag
            }
          }
        }
      }
    }
  }
  ${RepoFragment}
`

export const InstallationFragment = gql`
  fragment InstallationFragment on Installation {
    id
    context
    license
    autoUpgrade
    trackTag
    pingedAt
    repository { ...RepoFragment }
    user { ...UserFragment }
  }
  ${RepoFragment}
  ${UserFragment}
`

export const DependenciesFragment = gql`
  fragment DependenciesFragment on Dependencies {
    dependencies {
      name
      repo
      type
      version
      optional
    }
    providers
    application
    wirings { terraform helm }
  }
`

export const IntegrationFragment = gql`
  fragment IntegrationFragment on Integration {
    id
    name
    icon
    sourceUrl
    description
    tags { tag }
    publisher { ...PublisherFragment }
  }
  ${PublisherFragment}
`

export const ArtifactFragment = gql`
  fragment ArtifactFragment on Artifact {
    id
    name
    blob
    type
    platform
    arch
    filesize
    sha
    readme
    insertedAt
    updatedAt
  }
`

export const StepFragment = gql`
  fragment StepFragment on TestStep {
    id
    name
    status
    hasLogs
    description
    insertedAt
    updatedAt
  }
`

export const TestFragment = gql`
  fragment TestFragment on Test {
    id
    name
    promoteTag
    status
    insertedAt
    updatedAt
    steps { ...StepFragment }
  }
  ${StepFragment}
`
