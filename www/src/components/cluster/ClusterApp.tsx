import { ReactElement } from 'react'
import {
  ArrowTopRightIcon,
  GearTrainIcon,
  IconFrame,
  ListBoxItem,
} from '@pluralsh/design-system'
import { Flex, Span } from 'honorable'
import { useNavigate, useParams } from 'react-router-dom'

import { Repository } from '../../generated/graphql'
import { MoreMenu } from '../account/MoreMenu'

import ClusterAppHealth from './ClusterAppHealth'

type ClusterAppProps = {
  app: Repository
  consoleUrl?: string | null
  last: boolean
}

export function ClusterApp({
  app: {
    name, icon, darkIcon, installation,
  },
  consoleUrl,
  last,
}: ClusterAppProps): ReactElement {
  const navigate = useNavigate()
  const { clusterId } = useParams()

  const menuItems = {
    manageOnConsole: {
      icon: <ArrowTopRightIcon />,
      label: 'Manage on Console',
      onSelect: () => window.open(`${consoleUrl}/apps/${name}`, '_blank'),
    },
    appSettings: {
      icon: <GearTrainIcon />,
      label: 'App settings',
      onSelect: () => navigate(`/apps/${clusterId}/${name}`),
    },
  }

  return (
    <Flex
      gap="xsmall"
      align="center"
      padding="small"
      borderBottom={last ? undefined : '1px solid border'}
      cursor="pointer"
      onClick={() => navigate(`/apps/${clusterId}/${name}`)}
      _hover={{ backgroundColor: 'fill-one-hover' }}
    >
      <IconFrame
        icon={(
          <img
            src={darkIcon || icon || ''}
            width={16}
            height={16}
          />
        )}
        marginRight="xxsmall"
        size="medium"
        type="floating"
      />
      <Span
        body2
        fontWeight={600}
      >
        {name}
      </Span>
      <Flex grow={1} />
      <ClusterAppHealth
        pingedAt={installation?.pingedAt}
        marginHorizontal="xsmall"
      />
      <MoreMenu
        onSelectionChange={selectedKey => menuItems[selectedKey]?.onSelect()}
        floating
      >
        {Object.entries(menuItems).map(([key, { icon, label }]) => (
          <ListBoxItem
            key={key}
            textValue={label}
            label={label}
            leftContent={icon}
            color="blue"
          />
        ))}
      </MoreMenu>
    </Flex>
  )
}
