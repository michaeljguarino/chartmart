import { A, Flex } from 'honorable'
import moment from 'moment'
import { Button, Sidecar, SidecarItem } from '@pluralsh/design-system'
import { ReactElement, useContext } from 'react'

import QueueContext from '../../contexts/QueueContext'

import { Queue } from './Clusters'

export function ClustersSidecar(): ReactElement {
  const queue: Queue = useContext(QueueContext)

  return (
    <Flex
      gap={24}
      direction="column"
      overflow="hidden"
    >
      <Button
        secondary
        as={A}
        target="_blank"
        href={`https://${queue.domain}`}
        {...{
          '&:hover': {
            textDecoration: 'none',
          },
        }}
      >
        Launch Console
      </Button>
      <Sidecar heading="Metadata">
        <SidecarItem heading="Cluster name">{queue.name}</SidecarItem>
        <SidecarItem heading="Git url">
          <A
            inline
            target="_blank"
            noreferrer
            noopener
            href={queue.git}
          >
            {queue.git}
          </A>
        </SidecarItem>
        <SidecarItem heading="Acked">{queue.acked}</SidecarItem>
        <SidecarItem heading="Last pinged">
          {moment(queue.pingedAt).format('lll')}
        </SidecarItem>
      </Sidecar>
    </Flex>
  )
}
