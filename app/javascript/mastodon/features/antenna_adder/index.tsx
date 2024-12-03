import { useEffect, useState, useCallback } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchAntennas } from 'mastodon/actions/antennas';
import { createAntenna } from 'mastodon/actions/antennas_typed';
import {
  apiGetAccountAntennas,
  apiAddAccountToAntenna,
  apiAddExcludeAccountToAntenna,
  apiRemoveAccountFromAntenna,
  apiRemoveExcludeAccountFromAntenna,
  apiGetExcludeAccountAntennas,
} from 'mastodon/api/antennas';
import type { ApiAntennaJSON } from 'mastodon/api_types/antennas';
import { Button } from 'mastodon/components/button';
import { CheckBox } from 'mastodon/components/check_box';
import { Icon } from 'mastodon/components/icon';
import { IconButton } from 'mastodon/components/icon_button';
import { getOrderedAntennas } from 'mastodon/selectors/antennas';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newAntenna: {
    id: 'antennas.new_antenna_name',
    defaultMessage: 'New antenna name',
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
  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(id, e.target.checked);
    },
    [id, onChange],
  );

  return (
    // eslint-disable-next-line jsx-a11y/label-has-associated-control
    <label className='lists__item'>
      <div className='lists__item__title'>
        <Icon id='antenna-ul' icon={AntennaIcon} />
        <span>{title}</span>
      </div>

      <CheckBox value={id} checked={checked} onChange={handleChange} />
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
        <Icon id='antenna-ul' icon={AntennaIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newAntenna)}
        />
      </label>

      <Button text={intl.formatMessage(messages.createAntenna)} type='submit' />
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
    dispatch(fetchAntennas());

    const api = isExclude
      ? apiGetExcludeAccountAntennas
      : apiGetAccountAntennas;

    api(accountId)
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

      apiAddAccountToAntenna(antenna.id, accountId).catch(() => {
        setAntennaIds((currentAntennaIds) =>
          currentAntennaIds.filter((id) => id !== antenna.id),
        );
      });
    },
    [setAntennaIds, accountId],
  );

  return (
    <div className='modal-root__modal dialog-modal'>
      <div className='dialog-modal__header'>
        <IconButton
          className='dialog-modal__header__close'
          title={intl.formatMessage(messages.close)}
          icon='times'
          iconComponent={CloseIcon}
          onClick={onClose}
        />

        <span className='dialog-modal__header__title'>
          <FormattedMessage
            id='antennas.add_to_antennas'
            defaultMessage='Add {name} to antennas'
            values={{ name: <strong>@{account?.acct}</strong> }}
          />
        </span>
      </div>

      <div className='dialog-modal__content'>
        <div className='lists-scrollable'>
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
