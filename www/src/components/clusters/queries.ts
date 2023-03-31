import { gql } from '@apollo/client'

import { PageInfo } from '../../models/misc'
import { RolloutFragment, UpgradeFragment, UpgradeQueueFragment } from '../../models/upgrades'
import { UserFragment } from '../../models/user'

export const CLUSTERS = gql`
query {
  clusters(first: 100) {
    pageInfo { ...PageInfo }
    edges {
      node {
        id 
        name
        provider
        source
        gitUrl
        consoleUrl
        owner { ...UserFragment }
      }
    }
  }
}
${PageInfo}
${UserFragment}
`

export const QUEUES = gql`
  query Queues {
    upgradeQueues {
      ...UpgradeQueueFragment
    }
  }
  ${UpgradeQueueFragment}
`

export const QUEUE = gql`
  query Queue($id: ID!, $cursor: String) {
    upgradeQueue(id: $id) {
      ...UpgradeQueueFragment
      upgrades(after: $cursor, first: 50) {
        pageInfo { ...PageInfo }
        edges { node { ...UpgradeFragment } }
      }
    }
  }
  ${PageInfo}
  ${UpgradeQueueFragment}
  ${UpgradeFragment}
`

export const ROLLOUTS = gql`
  query Rollouts($repositoryId: ID!, $cursor: String) {
    rollouts(repositoryId: $repositoryId, after: $cursor, first: 50) {
      pageInfo { ...PageInfo }
      edges { node { ...RolloutFragment } }
    }
  }
  ${PageInfo}
  ${RolloutFragment}
`

export const UPGRADE_SUB = gql`
  subscription Upgrades($id: ID!) {
    upgrade(id: $id) { ...UpgradeFragment }
  }
  ${UpgradeFragment}
`

export const UPGRADE_QUEUE_SUB = gql`
  subscription {
    upgradeQueueDelta {
      delta
      payload { ...UpgradeQueueFragment }
    }
  }
  ${UpgradeQueueFragment}
`

export const ROLLOUT_SUB = gql`
  subscription Rollout($repositoryId: ID!) {
    rolloutDelta(repositoryId: $repositoryId) {
      delta
      payload { ...RolloutFragment }
    }
  }
  ${RolloutFragment}
`
