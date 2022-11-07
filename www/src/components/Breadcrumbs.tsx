import { useContext, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Anchor, Box, Text } from 'grommet'

import { lookahead } from '../utils/array'

import BreadcrumbsContext, { BreadcrumbsContextType } from '../contexts/BreadcrumbsContext'

function CrumbLink({ crumb: { url, text, disable } }: any) {
  const navigate = useNavigate()

  // TODO: new design does not cover the "disabled" state. Should it be removed?
  if (disable) {
    return (
      <Text
        size="small"
        color="dark-6"
      >
        {text}
      </Text>
    )
  }

  return (
    <Anchor
      size="small"
      onClick={() => navigate(url)}
    >
      {text}
    </Anchor>
  )
}

export function Breadcrumbs() {
  const { breadcrumbs } = useContext(BreadcrumbsContext)

  if (breadcrumbs.length === 0) return null

  const children = Array.from(lookahead(breadcrumbs, (crumb, next) => {
    if (next.url) {
      return [
        <CrumbLink
          key={crumb.url + crumb.text}
          crumb={crumb}
        />,
        <Text
          key={`${crumb.url + crumb.text}next`}
          size="small"
        >/
        </Text>,
      ]
    }

    return (
      <Text
        key={crumb.url + crumb.text}
        size="small"
        weight={700}
      >{crumb.text}
      </Text>
    )
  }) as any as any[]).flat()

  return (
    <Box
      flex={false}
      direction="row"
      gap="xsmall"
      align="center"
      pad={{ right: 'small', left: '1px' }}
    >
      {children}
    </Box>
  )
}

export default function BreadcrumbProvider({ children }: any) {
  const [breadcrumbs, setBreadcrumbs] = useState<any[]>([])
  const value = useMemo<BreadcrumbsContextType>(() => ({ breadcrumbs, setBreadcrumbs }), [breadcrumbs])

  return (
    <BreadcrumbsContext.Provider value={value}>
      {children}
    </BreadcrumbsContext.Provider>
  )
}
