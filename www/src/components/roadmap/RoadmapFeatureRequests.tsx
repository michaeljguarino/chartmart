import { useContext } from 'react'
import { PageTitle } from '@pluralsh/design-system'

import { Flex } from 'honorable'

import RoadmapContext from '../../contexts/RoadmapContext'

import RoadmapSearchBox from './RoadmapSearchBox'

import { LABEL_REQUEST } from './constants'

function RoadmapFeatureRequests() {
  const { pluralIssues, pluralConsoleIssues } = useContext(RoadmapContext)

  const issues = [...pluralIssues, ...pluralConsoleIssues].filter(issue => issue.labels.includes(LABEL_REQUEST))

  return (
    <Flex
      overflow="hidden"
      flexDirection="column"
      height="100%"
    >
      <PageTitle heading="Feature requests" />
      <RoadmapSearchBox
        displayAuthor
        displayVotes
        removeStateSorting
        label="Contribute to our roadmap by adding your feedback or voting."
        issues={issues}
      />
    </Flex>
  )
}

export default RoadmapFeatureRequests
