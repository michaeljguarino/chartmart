import { useEffect, useMemo } from 'react'
import { Errors } from 'forge-core'
import { useLocation, useNavigate, useParams } from 'react-router-dom'

import { Box, Text } from 'grommet'

import { LoopingLogo } from '../../../components/utils/AnimatedLogo'

import { ParamToService } from './types'
import { useCreateOauthIntegrationMutation } from '../../../generated/graphql'

function OauthError({ error, service }: any) {
  return (
    <Box
      fill
      gap="small"
      pad="medium"
    >
      <Text
        size="small"
        weight="bold"
      >
        Error creating oauth integration with {service}
      </Text>
      <Errors errors={error} />
    </Box>
  )
}

export function OauthCreator() {
  const navigate = useNavigate()
  const location = useLocation()
  const { service = '' } = useParams()
  const { redirectUri, code } = useMemo(() => {
    const params = new URLSearchParams(location.search)

    return {
      code: params.get('code'),
      redirectUri: `${window.location.origin}${window.location.pathname}`,
    }
  }, [location])
  const [mutation, { loading, data, error }] =
    useCreateOauthIntegrationMutation({
      variables: {
        attributes: { code, redirectUri, service: ParamToService[service] },
      },
    })

  useEffect(() => {
    mutation()
  }, [mutation])

  useEffect(() => {
    if (!error && data) {
      navigate('/accounts/edit/integrations')
    }
  }, [data, error, navigate])

  if (loading) return <LoopingLogo />

  if (error) {
    return (
      <OauthError
        error={error}
        service={service}
      />
    )
  }

  return (
    <Box
      fill
      align="center"
      justify="center"
    >
      <Text
        size="small"
        weight="bold"
      >
        Created {service} oauth integration
      </Text>
    </Box>
  )
}
