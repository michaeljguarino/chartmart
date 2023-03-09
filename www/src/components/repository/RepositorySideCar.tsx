import {
  Button,
  Div,
  Flex,
  P,
} from 'honorable'
import { BrowserIcon, CertificateIcon, GitHubLogoIcon } from '@pluralsh/design-system'

import { useRepositoryContext } from '../../contexts/RepositoryContext'

import { RepositoryActions } from './misc'

function RepositorySideCarButtons() {
  const repository = useRepositoryContext()

  return (
    <>
      <Button
        small
        tertiary
        as="a"
        target="_blank"
        href={repository.homepage}
        width="100%"
        justifyContent="flex-start"
        startIcon={(
          <BrowserIcon />
        )}
      >
        Website
      </Button>
      {repository.license?.url && (
        <Button
          small
          tertiary
          as="a"
          target="_blank"
          href={repository.license.url}
          width="100%"
          justifyContent="flex-start"
          startIcon={(
            <CertificateIcon />
          )}
        >
          License
        </Button>
      )}
      <Button
        small
        tertiary
        as="a"
        target="_blank"
        href={repository.gitUrl}
        width="100%"
        justifyContent="flex-start"
        startIcon={(
          <GitHubLogoIcon />
        )}
      >
        GitHub
      </Button>
    </>
  )
}

export function RepositorySideCar(props: any) {
  const repository = useRepositoryContext()

  return (
    <Div
      position="relative"
      width={200}
      paddingTop="medium"
      {...props}
    >
      <RepositoryActions />
      <Div
        marginTop="large"
        border="1px solid border"
        borderRadius="large"
        padding="medium"
      >
        <P
          overline
          color="text-xlight"
          wordBreak="break-word"
        >
          {repository.name} resources
        </P>
        <Flex
          marginTop="medium"
          width="100%"
          direction="column"
          align="flex-start"
        >
          <RepositorySideCarButtons />
        </Flex>
      </Div>
    </Div>
  )
}

export function RepositorySideCarCollapsed(props: any) {
  return (
    <Flex
      align="center"
      {...props}
    >
      <RepositoryActions />
      <Flex
        align="center"
        marginLeft="medium"
      >
        <RepositorySideCarButtons />
      </Flex>
    </Flex>
  )
}
