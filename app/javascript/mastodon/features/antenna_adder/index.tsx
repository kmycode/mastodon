import { useEffect, useState, useCallback, useId } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import { WifiXIcon, XIcon } from '@phosphor-icons/react';

import { Toggle } from '@/mastodon/components/form_fields';
import { fetchAntennas } from 'mastodon/actions/antennas';
import { createAntenna } from 'mastodon/actions/antennas_typed';
import {
  apiGetAccountAntennas,
  apiAddAccountToAntenna,
  apiRemoveAccountFromAntenna,
  apiGetExcludeAccountAntennas,
  apiAddExcludeAccountToAntenna,
  apiRemoveExcludeAccountFromAntenna,
} from 'mastodon/api/antennas';
import type { ApiAntennaJSON } from 'mastodon/api_types/antennas';
import { Button, IconButton } from 'mastodon/components/button';
import { Icon } from 'mastodon/components/icon';
import { NavigationFocusTarget } from 'mastodon/components/navigation_focus_target';
import { getOrderedAntennas } from 'mastodon/selectors/antennas';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newItem: {
    id: 'antennas.new_bookmark_category_name',
    defaultMessage: 'New bookmark_category name',
  },
  createAntenna: {
    id: 'antennas.create',
    defaultMessage: 'Create',
  },
  close: {
    id: 'lightbox.close',
    defaultMessage: 'Close',
  },
});

const AntennaItem: React.FC<{
  id: string;
  title: string;
  checked: boolean;
  onChange: (id: string, checked: boolean) => void;
}> = ({ id, title, checked, onChange }) => {
  const uniqueId = useId();

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(id, e.target.checked);
    },
    [id, onChange],
  );

  return (
    <label className='lists__item' htmlFor={uniqueId}>
      <div className='lists__item__title'>
        <Icon id='list-ul' icon={WifiXIcon} />
        <span>{title}</span>
      </div>

      <Toggle id={uniqueId} checked={checked} onChange={handleChange} />
    </label>
  );
};

const NewAntennaItem: React.FC<{
  onCreate: (antenna: ApiAntennaJSON) => void;
}> = ({ onCreate }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const [title, setTitle] = useState('');

  const handleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    if (title.trim().length === 0) {
      return;
    }

    void dispatch(createAntenna({ title })).then((result) => {
      if (isFulfilled(result)) {
        onCreate(result.payload);
        setTitle('');
      }

      return '';
    });
  }, [setTitle, dispatch, onCreate, title]);

  return (
    <form className='lists__item' onSubmit={handleSubmit}>
      <label className='lists__item__title'>
        <Icon id='list-ul' icon={WifiXIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newItem)}
        />
      </label>

      <Button type='submit' variant='solid' color='accent' size='sm'>
        {intl.formatMessage(messages.createAntenna)}
      </Button>
    </form>
  );
};

const AntennaAdder: React.FC<{
  accountId: string;
  isExclude: boolean;
  onClose: () => void;
}> = ({ accountId, isExclude, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const account = useAppSelector((state) => state.accounts.get(accountId));
  const antennas = useAppSelector((state) => getOrderedAntennas(state));
  const [antennaIds, setAntennaIds] = useState<string[]>([]);

  useEffect(() => {
    void dispatch(fetchAntennas());

    const func = isExclude
      ? apiGetExcludeAccountAntennas
      : apiGetAccountAntennas;

    func(accountId)
      .then((data) => {
        setAntennaIds(data.map((l) => l.id));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [dispatch, setAntennaIds, accountId, isExclude]);

  const handleToggle = useCallback(
    (antennaId: string, checked: boolean) => {
      if (checked) {
        setAntennaIds((currentAntennaIds) => [antennaId, ...currentAntennaIds]);

        const func = isExclude
          ? apiAddExcludeAccountToAntenna
          : apiAddAccountToAntenna;

        func(antennaId, accountId).catch(() => {
          setAntennaIds((currentAntennaIds) =>
            currentAntennaIds.filter((id) => id !== antennaId),
          );
        });
      } else {
        setAntennaIds((currentAntennaIds) =>
          currentAntennaIds.filter((id) => id !== antennaId),
        );

        const func = isExclude
          ? apiRemoveExcludeAccountFromAntenna
          : apiRemoveAccountFromAntenna;

        func(antennaId, accountId).catch(() => {
          setAntennaIds((currentAntennaIds) => [
            antennaId,
            ...currentAntennaIds,
          ]);
        });
      }
    },
    [setAntennaIds, accountId, isExclude],
  );

  const handleCreate = useCallback(
    (antenna: ApiAntennaJSON) => {
      setAntennaIds((currentAntennaIds) => [antenna.id, ...currentAntennaIds]);

      const func = isExclude
        ? apiAddExcludeAccountToAntenna
        : apiAddAccountToAntenna;

      func(antenna.id, accountId).catch(() => {
        setAntennaIds((currentAntennaIds) =>
          currentAntennaIds.filter((id) => id !== antenna.id),
        );
      });
    },
    [setAntennaIds, accountId, isExclude],
  );

  return (
    <div className='modal-root__modal dialog-modal'>
      <div className='dialog-modal__header'>
        <IconButton
          className='dialog-modal__header__close'
          icon={XIcon}
          onClick={onClose}
          size='sm'
          variant='ghost'
        >
          {intl.formatMessage(messages.close)}
        </IconButton>

        <NavigationFocusTarget as='h1' className='dialog-modal__header__title'>
          <FormattedMessage
            id='antennas.add_to_antennas'
            defaultMessage='Add {name} to antennas'
            values={{ name: <strong>{account?.display_name}</strong> }}
          />
        </NavigationFocusTarget>
      </div>

      <div className='dialog-modal__content'>
        <div className='antennas-scrollable'>
          <NewAntennaItem onCreate={handleCreate} />

          {antennas.map((antenna) => (
            <AntennaItem
              key={antenna.id}
              id={antenna.id}
              title={antenna.title}
              checked={antennaIds.includes(antenna.id)}
              onChange={handleToggle}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default AntennaAdder;
