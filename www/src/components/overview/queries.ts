import { gql } from '@apollo/client'

import { PageInfo } from '../../models/misc'
import { UpgradeFragment, UpgradeQueueFragment } from '../../models/upgrades'
import { ImpersonationPolicy, UserFragment } from '../../models/user'

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
        pingedAt
        gitUrl
        consoleUrl
        owner {
          id
          name
          email
          avatar
          serviceAccount
          impersonationPolicy { ...ImpersonationPolicy }
          hasShell
        }
        queue { 
          ...UpgradeQueueFragment 
          upgrades(first: 3) { 
            edges { 
              node { 
                ...UpgradeFragment 
              } 
            } 
          } 
        }
      }
    }
  }
}
${PageInfo}
${UserFragment}
${ImpersonationPolicy}
${UpgradeQueueFragment}
${UpgradeFragment}
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
