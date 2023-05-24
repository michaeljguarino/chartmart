import { createContext, useMemo } from 'react'
import { useQuery } from '@apollo/client'
import styled from 'styled-components'

import {
  Cluster,
  RootQueryType,
  RootQueryTypeClustersArgs,
} from '../generated/graphql'
import LoadingIndicator from '../components/utils/LoadingIndicator'
import { CLUSTERS } from '../components/overview/queries'

type ClustersContextType = {
  clusters: Cluster[]
  refetchClusters?: () => Promise<any>
}

const ClustersContext = createContext<ClustersContextType>({
  clusters: [],
})

const Error = styled.div(({ theme }) => ({
  ...theme.partials.text.body2,
  display: 'flex',
  flexGrow: 1,
  justifyContent: 'center',
  alignItems: 'center',
}))

export function ClustersContextProvider({ children }) {
  const { data, loading, error, refetch } = useQuery<
    Pick<RootQueryType, 'clusters'>,
    RootQueryTypeClustersArgs
  >(CLUSTERS, {
    pollInterval: 30_000,
  })

  const clustersContextValue = useMemo<ClustersContextType>(() => {
    const clusters =
      data?.clusters?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is Cluster => !!node) || []

    return { clusters, refetchClusters: refetch }
  }, [data, refetch])

  if (error) return <Error>{error.message}</Error>
  if (!data && loading) return <LoadingIndicator />

  return (
    <ClustersContext.Provider value={clustersContextValue}>
      {children}
    </ClustersContext.Provider>
  )
}

export default ClustersContext
